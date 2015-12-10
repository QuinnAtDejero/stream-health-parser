################################################################################
#
# Class: Stream Health Parser
# 
# This class takes a file handler, and reads every line of the file. With each line
# it creates a LiveStat object and saves them in an array.
#
################################################################################
#
# NOTES:
#
# 7 different 'LiveStats' log statement categories:
# 
# 'SD' - System Details
# 'CD' - connection meta details
# 'CN' - cell connection network stats
# 'WF' - wifi network stats
# 'CX' - connection transmission stats
# 'EN' - encoder/video stats
# 'GP' - GPS data
#
################################################################################
class StreamHealthParser

	def initialize(fileHandler)
		@live_stats = Array.new
		@lost_frames = 0
		@total_time = nil

		start_time = ""
		end_time = ""
		current_frame_size = nil
		current_frame_size_start_time = nil
		frame_size_changes = 0
		max_connection_bitrate = 0

		# Metrics
		@frame_lost_metric = 0
		@frame_size_change_metric = 1
		@frame_size_metric = 0
		@overall_health = "Poor"

		current_category_hash  = {"SD"=>nil,"CD"=>nil,"CN"=>nil,"WF"=>nil,"CX"=>nil,"EN"=>nil,"GP"=>nil}
		frame_size_hash = {"180"=>0, "240"=>0, "all-other"=>0}

		fileHandler.each_line do |line|
			live_stat = LiveStat.new(line)

			if live_stat.category == "SD" && live_stat.data["Action"] == "APP.STARTUP"
				start_time = live_stat.timestamp
			end

			if live_stat.category == "SD" && live_stat.data["Action"] == "APP.SHUTDOWN"
				end_time = live_stat.timestamp
				@total_time = calculate_total_time(start_time, end_time)
			end

			# Filter out anything within the first 30 seconds
			if is_within_x_seconds(start_time, live_stat.timestamp, 30) == false

				# Filter out excess live_stats
				if current_category_hash[live_stat.category] == nil || is_within_x_seconds(current_category_hash[live_stat.category].timestamp, live_stat.timestamp, 5) == false
					# Not within 5 seconds OR 
					# there is no current live_stat for this category THEREFORE
					# save this live stat in my array AND make it the current live stat
					current_category_hash[live_stat.category] = live_stat
					@live_stats.push(live_stat)

					if live_stat.category == "EN"
						if(live_stat.data[:number_of_lost_video_frames].to_i > 0)
							@lost_frames += 1
						end
					end

					if live_stat.category == "CX"
						# puts "Target: #{live_stat.data["TargetBPS"]} Smooth: #{live_stat.data["ReceivedBPS-Smoothed"]} Instant: #{live_stat.data["ReceivedBPS-Instantaneous"]}"
						if live_stat.data[:received_bps_smoothed].to_i > max_connection_bitrate
							max_connection_bitrate = live_stat.data[:received_bps_instantaneous].to_i
						end
					end
				end

				if live_stat.category == "EN"
					if live_stat.data["LiveVideo"] != nil
						live_video_data = live_stat.data["LiveVideo"]
						frame_size = parse_frame_size(live_video_data)
						if current_frame_size == nil
							current_frame_size = frame_size
							current_frame_size_start_time = live_stat.timestamp
						elsif current_frame_size != frame_size
							# Get time in current frame size and add those seconds to the hash
							time_in_frame = calculate_total_time current_frame_size_start_time, live_stat.timestamp
							seconds_in_frame = time_in_frame[1] + (time_in_frame[0] * 60)

							if current_frame_size == "180"
								frame_size_hash["180"] += seconds_in_frame.to_i
							elsif current_frame_size == "240"
								frame_size_hash["240"] += seconds_in_frame.to_i
							else
								frame_size_hash["all-other"] += seconds_in_frame.to_i
							end

							current_frame_size = frame_size
							current_frame_size_start_time live_stat.timestamp
							frame_size_changes += 1
						end
					end
				end
			end

			if @total_time != nil
				# Shutdown message was recieved
				# Add last frame size time to hash
				time_in_frame = calculate_total_time current_frame_size_start_time, live_stat.timestamp
				seconds_in_frame = time_in_frame[1] + (time_in_frame[0] * 60)
				if current_frame_size == "180"
					frame_size_hash["180"] += seconds_in_frame.to_i
				elsif current_frame_size == "240"
					frame_size_hash["240"] += seconds_in_frame.to_i
				else
					frame_size_hash["all-other"] += seconds_in_frame.to_i
				end
			end
		end

		# Calculations
		@frame_lost_metric = 0.5 ** @lost_frames.to_f

		total_seconds = @total_time[1].to_i + (@total_time[0] * 60).to_i
		frame_size_changes_per_second = frame_size_changes / total_seconds
		@frame_size_change_metric = 1.0 - frame_size_changes_per_second.to_f

		k = calculate_k max_connection_bitrate

		@frame_size_metric = k.to_f * total_seconds.to_f / (16.0 * frame_size_hash["180"].to_f + 8.0 * frame_size_hash["240"].to_f + frame_size_hash["all-other"].to_f)

		least_value = [@frame_lost_metric, @frame_size_change_metric, @frame_size_metric].min
		percentage = least_value * 100

		if percentage >= 90
			@overall_health = "Good"
		elsif percentage < 90 && percentage >= 25
			@overall_health = "Marginal"
		end

		fileHandler.close
	end

	# GETTERS
	def live_stats
		return @live_stats
	end
	def lost_frames
		return @lost_frames
	end
	def stats_text
		return "Lost Frames: #{@lost_frames}"
	end
	def total_time
		return @total_time
	end
	# GET METRICS
	def frame_lost_metric
		return @frame_lost_metric
	end
	def frame_size_change_metric
		return @frame_size_change_metric
	end
	def frame_size_metric
		return @frame_size_metric
	end
	def overall_health
		return @overall_health
	end

private
	# HELPERS
	def to_s
		return "Live Stats: #{@live_stats}, Lost Frames: #{@lost_frames}"
	end

	def get_minimum_time(timestamp)
		time_pieces = timestamp.to_s.split(".")
		minutes = Integer(time_pieces[0])
		seconds = Integer(time_pieces[1])

		if seconds < 30
			time_pieces[1] = (seconds += 30).to_s
		elsif seconds == 30
			time_pieces[1] = "00"
			time_pieces[0] = (minutes += 1).to_s
		else
			time_pieces[1] = (seconds -= 30).to_s
			time_pieces[0] = (minutes += 1).to_s
		end
		return time_pieces.join(".")
	end

	# Check to see if a two timestamps are within x seconds of each other
	def is_within_x_seconds(start_time, end_time, x_seconds)
		result = false

		start_time_pieces = start_time.split(".")
		end_time_pieces = end_time.split(".")

		start_time_minutes = start_time_pieces[0].to_i
		start_time_seconds = start_time_pieces[1].to_i

		end_time_minutes = end_time_pieces[0].to_i
		end_time_seconds = end_time_pieces[1].to_i

		if(end_time_seconds <= start_time_seconds)
			end_time_seconds += 60
			end_time_minutes -= 1
		end

		total_minutes = end_time_minutes - start_time_minutes
		total_seconds = end_time_seconds - start_time_seconds

		if(total_seconds >= 60)
			total_seconds -= 60
			total_minutes += 1
		end

		if total_minutes > 0 || total_seconds >= x_seconds
			result = false
		elsif total_minutes == 0 && total_seconds < x_seconds
			result = true
		end

		result
	end

	# Calculate total time of stream
	def calculate_total_time(start_time, end_time)
		start_time_pieces = start_time.split(".")
		end_time_pieces = end_time.split(".")

		start_time_minutes = start_time_pieces[0].to_i
		start_time_seconds = start_time_pieces[1].to_i

		end_time_minutes = end_time_pieces[0].to_i
		end_time_seconds = end_time_pieces[1].to_i

		if(end_time_seconds < start_time_seconds)
			end_time_seconds += 60
			end_time_minutes -= 1
		end

		total_minutes = end_time_minutes - start_time_minutes
		total_seconds = end_time_seconds - start_time_seconds

		if(total_seconds >= 60)
			total_seconds -= 60
			total_minutes += 1
		end

		total_time = [total_minutes, total_seconds]
	end

	def parse_frame_size(video_data)
		x_index = video_data.index("x") + 1
		t_index = video_data.index("t")
		frame_size = video_data[x_index, t_index - x_index]
		return frame_size
	end

	def calculate_k(max_connection_bitrate)
		k = 0
		if max_connection_bitrate <= 500000
			k = 16
		elsif max_connection_bitrate <= 1100000
			k = 8
		else
			k = 1
		end
		return k
	end
end