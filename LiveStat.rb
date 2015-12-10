################################################################################
# Class: LiveStat
# 
# This class takes a single line from the log file in the initialization
# of the object, and parses it into a few different attributes. They include:
# @timestamp
# @software_version
# @category
# @data
#
# All these attributes have "Getters" so they can be used by the main application
################################################################################
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
# All 'LiveStats' logs lines start the same:
# i         ii             iii
# |-------- |--------      |--
# 53.38.818 3.1.0.DEV LVST SD
#
# i   - timestamp (UTC)   [format:  MM.SS.mil]
# ii  - Tx software version
# iii - LiveStats category:  [SD|CD|CN|WF|CX|EN|GP]
################################################################################

class LiveStat

public 

	def initialize(line)
		@line = line
		pieces = @line.split(" ");

		@timestamp = pieces[0]
		@software_version = "#{pieces[1]} #{pieces[2]}" 
		@category = pieces[3]
		@data = Hash.new()

		# Create data string
		data_string = ""
		counter = 4
		while counter < pieces.count
			data_string << "#{pieces[counter]} "
			counter += 1
		end
		# Remove trailing space
		data_string = data_string.strip!

		case @category
			when "SD"
				process_sd(data_string)
			when "CD"
				process_cd(data_string)
			when "CN"
				process_cn(data_string)
			when "WF"
				process_wf(data_string)
			when "CX"
				process_cx(data_string)
			when "EN"
				process_en(data_string)
			when "GP"
				process_gp(data_string)
		end
	end

	# GETTERS
	def timestamp
		return @timestamp
	end
	def software_version
		return @software_version
	end
	def category
		return @category
	end
	def data
		return @data
	end

	# SETTERS
	def timestamp=(value)
		return @timestamp
	end
	def software_version=(value)
		return @software_version
	end
	def category=(value)
		return @category
	end

	# PUBLIC FUNCTIONS
	def to_s
		return "Timestamp: #{@timestamp}, Software Version: #{@software_version}, Category: #{@category}, Data: #{@data}"
	end

private

	# HELPERS
	def parse_data_container(data_container)
		data_stripped = data_container.tr('[]', '')
		data_pieces = data_stripped.split('|')
		return data_pieces
	end
	def parse_key_value(key_value)
		pieces = key_value.split("=")
		if pieces.count > 0
			pair = { pieces[0] => pieces[1] }
		else
			pair = nil
		end
		return pair
	end

###################################################
# 'SD' - System Details
###################################################
#      Info:  High-level system info/events
# Frequency:  On demand
#
# Examples:
# 40.34.992 3.1.0.DEV LVST SD [CoreState=DCTxS_STARTUP_CONNECTION_DIAL]
# 40.35.098 3.1.0.DEV LVST SD [Action=APP.STARTUP]
# 00.41.595 3.1.0.DEV LVST SD [Action=STREAM.START|GTG=3000]
#
# One [Action=X] per SD line.
# Valid options:
# 
# [Action=<action>]  where <action> = 'APP.STARTUP'           -> Tx App startup
#                                     'APP.SHUTDOWN'          -> Tx App shutdown
#                                     'STREAM.START|GTG=x'    -> Live Stream Start  (with GTG @ X milliseconds)
#                                     'STREAM.STOP'           -> Live Stream Stop
#                                     'SNF.START'             -> S&F Clip Transfer Start
#                                     'SNF.STOP'              -> S&F Clip Transfer Stop
#                                     'FT.START'              -> File Transfer Start
#                                     'FT.STOP'               -> File Transfer Stop
###################################################
	def process_sd(data)
		if !data
			return false
		end
		data_containers = data.split("] [")

		data_containers.each do |container|
			data_pieces = parse_data_container(container)

			data_pieces.each do |piece|
				pair = parse_key_value(piece)
				if pair != nil
					@data.merge!(pair)
				end
			end
		end
	end
	
###################################################
# 'CD' - connection meta details
###################################################
#      Info:  Connection/Network Interface details  (i.e. modem type/model/firmware/imei)
# Frequency:  Once, as soon as NI connects.
# 
# Examples:
# 40.55.084 3.1.0.DEV LVST CD [0|9|ETHERNET] [NI.Type=ETH] [NI.Name=Intel(R) 82579V Gigabit Network Connection]
# 40.55.229 3.1.0.DEV LVST CD [1|9|WLAN] [NI.Type=WFI] [NI.Name=ASUS EZ N 802.11b/g/n Wireless USB Adapter]
# 40.57.104 3.1.0.DEV LVST CD [3|9|UMTS] [NI.Type=CEL] [NI.Name=Sierra Wireless HSPA Modem #2] [Modem.CellType=CTYPE__GSM] [Modem.Model=MC7700] [Modem.SN=012626000053064] [Modem.Manufacturer=Sierra Wireless, Incorporated] [Modem.FW=SWI9200X_03.05.20.05ap r5847 carmd-en-10527 2013/06/21 17:02:10] [Modem.AttachedToUSBExtender=false] [SIM.Carrier=Telus] [SIM.ICCID=8912230000010823953] [SIM.IMSI=302220000812419]
#                              | | |     |
#                              | | |     Start of [Key=Value] list
#                              | | |
#                              | | Connection Type (valid options:  [CELL|UMTS|CDMA|ETHERNET|WLAN|IPHONE|MB_ETH|RNDIS_ETH])
#                              | |
#                              | Connection Generation # (i.e. misc session data id) (re-generated on each new connection index mapping)
#                              |
#                              Connection #  (same # in Tx UI and Graph logs)
#
# Valid Keys:
#     'NI.Type'                       -> Network interface type.  With values:    [CEL|ETH|WFI|NDS|MB]
#     'NI.Name'                       -> Network interface name.  (i.e. Windows device friendly name)
#     'Modem.CellType'                -> Modem Cell Type.         With values:    [CTYPE__GSM|CTYPE__CDMA|CTYPE__UNKNOWN]
#     'Modem.Model'                   -> Modem model.
#     'Modem.SN'                      -> Modem Serial #   (IMEI if CellType==CTYPE__GSM;  ESN if CellType=CTYPE__CDMA)
#     'Modem.Manufacturer'            -> Modem Manufacturer
#     'Modem.FW'                      -> Modem firmware revision
#     'Modem.AttachedToUSBExtender'   -> bool (true|false)    -> whether or not this modem is attached to a connected USB Extender
#     'SIM.Carrier'                   -> SIM/account carrier name
#     'SIM.ICCID'                     -> SIM ICCID
#     'SIM.IMSI'                      -> SIM IMSI
###################################################
	def process_cd(data)
		if !data
			return false
		end
		data_containers = data.split("] [")

		data_containers.each do |container|

			if container.index('=') != nil
				data_pieces = parse_data_container(container)
				data_pieces.each do |piece|
					pair = parse_key_value(piece)
					if pair != nil
						@data.merge!(pair)
					end
				end
			else
				data_pieces = parse_data_container(container)
				@data[:connection_number] = data_pieces[0]
				@data[:onnection_generation] = data_pieces[1]
				@data[:connection_type] = data_pieces[2]
			end
		end
	end

###################################################
# 'CN' - cell connection network stats
# ###################################################
#      Info:  Cell Connection Network stats
# Frequency:  Every 10 seconds
#   Example:
#
# data [E-P] is in KEY=VALUE format  ('KEY' strings are constant)
#                              A B C      D                     E         F        G        H       I                         J             K       L       M         N                O
#                              | | |---   |-------------------- |-------- |------- |------- |------ |------------------------ |------------ |------ |------ |-------- |--------------- |------
# 54.53.502 3.1.0.DEV LVST CN [1|9|UMTS] [STATUS=NIS__CONNECTED|CTECH=LTE|RSSI=-65|RSCP=-77|PSC=224|NREG=NREG_REGISTERED_HOME|PROVIDER=Bell|MCC=302|MNC=610|LAC=55510|CellID=138861314|TEMP=31]
#
# A - connection number/index
# B - connection generation number (i.e. misc data session id)
# C - Connection Type (valid options:  [CELL|UMTS|CDMA|ETHERNET|WLAN|IPHONE|MB_ETH|RNDIS_ETH])
# D - network interface status.  options:
#                     "NIS__UNKNOWN"
#                     "NIS__NOT_PRESENT"
#                     "NIS__NO_SIM"
#                     "NIS__SIM_LOCKED"
#                     "NIS__SIM_ERROR"
#                     "NIS__INVALID_APN"
#                     "NIS__DISABLED"
#                     "NIS__INITIALIZING"
#                     "NIS__SEARCHING"
#                     "NIS__CONNECTING"
#                     "NIS__CONNECTED"
#                     "NIS__DISCONNECTING"
#                     "NIS__DISCONNECTED"
#                     "NIS__RESETTING"
# E - cell technology.  options:
#                     "NONE"
#                     "GPRS"
#                     "EDGE"
#                     "UMTS"
#                     "HSDPA"
#                     "HSUPA"
#                     "HSPA"
#                     "HSPA+"
#                     "LTE"
#                     "CDMA_1X"
#                     "CDMA_1XEVDO"
#                     "CDMA_1XEVDOrA"
#                     "CDMA_1XEVDOrB"
#                     "CDMA_1XEVDV"
#                     "CDMA_3XRTT"
#                     "CDMA_UMB"
# F - RSSI (dBm)
# G - RSCP = Received Signal Code Power (dBm)
# H - PSC = Primary Scrambling Code
# I - network registration.  options:
#                     "NREG_UNKNOWN"
#                     "NREG_NOT_REGISTERED"
#                     "NREG_SEARCHING"
#                     "NREG_REGISTERED_HOME"
#                     "NREG_REGISTERED_ROAMING"
#                     "NREG_DENIED"
# J - Network Provider
# K - MCC (Network)
# L - MNC (Network)
# M - LAC (Network)
# N - CellID (Network)
# O - modem temperature (C)
###################################################
	def process_cn(data)
		if !data
			return false
		end
		data_containers = data.split("] [")

		data_containers.each do |container|

			if container.index('=') != nil
				data_pieces = parse_data_container(container)
				data_pieces.each do |piece|
					pair = parse_key_value(piece)
					if pair != nil
						@data.merge!(pair)
					end
				end
			else
				data_pieces = parse_data_container(container)
				@data[:connection_number] = data_pieces[0]
				@data[:connection_generation] = data_pieces[1]
				@data[:connection_type] = data_pieces[2]
			end
		end
	end

###################################################
# 'WF' - wifi network stats
###################################################
#      Info:  WiFi network status
# Frequency:  Every 10 seconds
#
#                                                                                                           /------------------------------------------------------ 'Development' ------------------------------------------------------------\   /-------------------------------------------------------- 'Production' ----------------------------------------------------------\   /---------------------- 'DejNAB2.4' -----------------------\   /------------------------------------------------------ 'Administration' ------------------------------------------------------------\   /------------------------------------------ 'GuestsOfDejero' ---------------------------------------------\   /-------------------- 'SqueezeBox' -------------------------\
#                              A                                          B   C              D              f  g           h   i               j  k                 l    k                 l    k                 l    k                 l        f  g          h   i               j  k                 l    k                 l    k                 l    k                 l        f  g         h   i               j  k                 l        f  g              h   i               j  k                 l    k                 l    k                 l    k                 l        f  g              h   i           j  k                 l    k                 l    k                 l        f  g              h   i           j  k                 l
#                              |                                          |   |              |              |- |---------- |-- |-------        |  |---------------- |--  |---------------- |--  |---------------- |--  |---------------- |--      |- |--------- |-- |-------        |  |---------------- |--  |---------------- |--  |---------------- |--  |---------------- |--      |- |-------- |-- |-------        |  |---------------- |--      |- |------------- |-- |-------        |  |---------------- |--  |---------------- |--  |---------------- |--  |---------------- |--      |- |------------- |-- |---        |  |---------------- |--  |---------------- |--  |---------------- |--      |- |------------- |-- |---        |  |---------------- |--
# 19.51.334 3.1.0.DEV LVST WF [ASUS EZ N 802.11b/g/n Wireless USB Adapter|6] [Connected=true(Development)] [23|Development|-50|WPA2-PSK|BSSIDs=4=[24-A4-3C-16-6D-81(-49);24-A4-3C-16-60-E1(-65);24-A4-3C-16-69-41(-71);24-A4-3C-16-68-C1(-72);]] [24|Production|-54|WPA2-PSK|BSSIDs=4=[24-A4-3C-16-6D-82(-49);24-A4-3C-16-69-42(-71);24-A4-3C-16-60-E2(-65);24-A4-3C-16-68-C2(-73);]] [24|DejNAB2.4|-54|WPA2-PSK|BSSIDs=1=[10-FE-ED-E5-E6-33(-49);]] [25|Administration|-54|WPA2-PSK|BSSIDs=4=[24-A4-3C-16-6D-80(-49);24-A4-3C-16-69-40(-71);24-A4-3C-16-60-E0(-66);24-A4-3C-16-68-C0(-73);]] [26|GuestsOfDejero|-54|OPEN|BSSIDs=3=[24-A4-3C-16-6D-83(-49);24-A4-3C-16-69-43(-71);24-A4-3C-16-60-E3(-65);]] [26|SqueezeBox|-62|WPA2-PSK|BSSIDs=1=[A0-F3-C1-2B-C9-91(-57);]]
#
# A - WiFi interface name
# B - the number of wifi networks scanned and reported on this line
# C - connected status  [Connected=true|false]
# D - currently connected SSID:
#         if connected: "[Connected=true(D)]"
#         otherwise:    "[Connected=false()]"
#
# then for each wifi network (data for up to B networks follows):
#     (data for each wifi network within [])
# f - time (ms) since this network was detected.  So, this network data was from time point (i - f).
# g - SSID
# h - RSSI (dBm)
# i - authentication method
# j - # of BSSID's detected on this wifi ap
#
# then for each BSSID reported for this wifi ap: BSSID(RSSI);
#     (semicolon-delimited list within [])
# k - BSSID
# l - RSSI (dBm)
# [f-l] is reported for each wifi network
###################################################
	def process_wf(data)
		if !data
			return false
		end
		data_containers = data.split("] [")

		if data_containers[0]
			data_pieces = parse_data_container(data_containers[0])
			@data[:wifi_interface_name] = data_pieces[0]
			@data[:count_wifi_networks_scanned] = data_pieces[1]

			# @data.merge! ({"WifiInterfaceName" => data_pieces[0]})
			# @data.merge! ({"CountWifiNetworksScanned" => data_pieces[1]})
		end

		if data_containers[1]
			data_pieces = parse_data_container(data_containers[1])
			data_pieces.each do |piece|
				pair = parse_key_value(piece)
				if pair != nil
					@data.merge!(pair)
				end
			end
		end

		if data_containers.count > 2
			# We have a list of wifi connections - let's parse them
			wifi_connections = Hash.new
			counter = 3
			while counter < data_containers.count
				wifi_connection = Hash.new
				connection = data_containers[counter].tr_s(']]', ']')

				wifi_connection_pieces = connection.split("|")
				wifi_connection[:time_since_detected] = wifi_connection_pieces[0]
				wifi_connection[:ssid] = wifi_connection_pieces[1]
				wifi_connection[:rssi] = wifi_connection_pieces[2]
				wifi_connection[:authentication_method] = wifi_connection_pieces[3]

				bssids_pieces = wifi_connection_pieces[4].split("=")
				wifi_connection[:bssids_count] = bssids_pieces[1]

				bssids_string = bssids_pieces[2].tr('[]', '')
				wifi_connections[:bssids] = bssids_string

				@data.merge! (wifi_connection)
				counter += 1
			end
		end
	end

###################################################
# 'CX' - connection transmission stats
###################################################
#      Info:  Connection transmission stats
# Frequency:  Every 1 second while streaming (reduced to every 10 seconds while Tx is Idle)
#
# Examples:
#                              A B  C D       E     F      G     H  I J      K       L M       N       O
#                              | |- | |------ |---- |----- |---- |  | |----- |------ | |------ |------ |---
# 56.14.406 3.1.0.DEV LVST CX [1|10|6|2500000|33.00|100.00|22.14|0| 7|1.5841|5000000|0|2615747|2603464|1.00]
# 56.43.315 3.1.0.DEV LVST CX [0|10|6|2500000|44.58|100.00|32.90|0|10|1.0615|5000000|0|2549270|2569112|1.00]
#
# 0 A - connection number/index
# 1 B - connection generation number (i.e. misc data session id)
# 2 C - Connection State  (0=INITIALIZING; 1=DIALING; 2=IDLE; 3=TIME_SYNC; 4=TESTING; 5=EMERGENCY; 6=ACTIVE; 7=DEAD; 8=SHUTTING_DOWN)
# 3 D - Target BPS
# 4 E - 2 Sigma Latency (ms)
# 5 F - Stream Health %         [0, 100]
# 6 G - Mean Latency (ms)
# 7 H - Missing packet count
# 8 I - total packet count
# 9 J - latency jitter (ms)
# 10 K - CAThresh BPS (Congestion Avoidance Threashold BPS)
# 11 L - Remote Control BPS
# 12 M - Received BPS (smoothed)
# 13 N - Received BPS (instantaneous)
# 14 O - Reliability %           [0.0, 1.0]
# NOTE: Data [A-O] delimited by '|' within []
###################################################
	def process_cx(data)
		if !data
			return false
		end
		
		data_containers = data.split("] [")

		data_containers.each do |container|
			data_pieces = parse_data_container(container)
			@data[:connection_number] = data_pieces[0]
			@data[:generation_number] = data_pieces[1]
			@data[:connection_state] = data_pieces[2]
			@data[:target_bps] = data_pieces[3]
			@data[:sigma_latency] = data_pieces[4]
			@data[:stream_health_percentage] = data_pieces[5]
			@data[:mean_latency] = data_pieces[6]
			@data[:missing_packetCount] = data_pieces[7]
			@data[:total_packet_count] = data_pieces[8]
			@data[:latency_jitter] = data_pieces[9]
			@data[:cathresh_bps] = data_pieces[10]
			@data[:remote_control_bps] = data_pieces[11]
			@data[:received_bps_smoothed] = data_pieces[12]
			@data[:received_bps_instantaneous] = data_pieces[13]
			@data[:reliability] = data_pieces[14]
		end

	end

###################################################
# 'EN' - encoder/video stats:
###################################################
#      Info:  Encoder/video stats (while transmitting)
# Frequency:  Every 1 second while streaming
#
# Example:
#                              A   B       C D       E       F      G H I    J   K L M N          O                                                     P
#                              |-- |------ | |------ |------ |----- | | |--- |-- | | | |-------   |--------------------------------------------------   |---------------------------------------------
# 56.15.732 3.1.0.DEV LVST EN [174|5000000|0|4038667|4009768|128144|0|*|7498|100|0|0|0|0.831324] [LiveVideo=1920x1080t@29.97(30000/1001)|h264|yuv420p] [LiveAudio=48000Hz|stereo(2)|opus|s16|(1000|20)]
#
# 0 A - StreamID
# 1 B - Total Target BPS (all connections)
# 2 C - Backlog BPS
# 3 D - Encoder BPS (what we tell the encoder)
# 4 E - Video BPS
# 5 F - Audio BPS
# 6 G - Encoder BPS (bitrate read back from the encoder)
# 7 H - encoder mode (A=audio-only mode; K=keyframe-only mode; *=audio&video)
# 8 I - total broadcast time (ms)
# 9 J - network health % / buffer fill %    [0,100]
# 10 K - IFB GTG delay (ms)
# 11 L - IFB sound level (percentage)
# 12 M - num lost video frames (reported from Server:  StatReport::GetNumLostVideoFrames())
# 13 N - video SSIM %  [0,1]  (1-second rolling average)
#
# O - Optional additional Video parameters:
#     [LiveVideo=X]
#         -where X is the current live video transport format
#         -this is added on demand when the transport format changes
#
# P - Optional additional Audio parameters:
#     [LiveAudio=X]
#         -where X is the current live audio transport format
#         -this is added on demand when the transport format changes
#
# NOTE: Data [A-N] delimited by '|' within []
###################################################
	def process_en(data)
		if !data
			return false
		end
		
		data_containers = data.split("] [")

		if data_containers[0]
			data_pieces = parse_data_container(data_containers[0])
			@data[:stream_id] = data_pieces[0]
			@data[:total_target_bps] = data_pieces[1]
			@data[:backlog_bps] = data_pieces[2]
			@data[:encoder_bps_to] = data_pieces[3]
			@data[:video_bps] = data_pieces[4]
			@data[:audio_bps] = data_pieces[5]
			@data[:encoder_bps_from] = data_pieces[6]
			@data[:encoder_mode] = data_pieces[7]
			@data[:total_broadcast_time] = data_pieces[8]
			@data[:network_health] = data_pieces[9]
			@data[:ifbgtg_delay] = data_pieces[10]
			@data[:ifb_sound_level] = data_pieces[11]
			@data[:number_of_lost_video_frames] = data_pieces[12]
			@data[:video_ssim] = data_pieces[13]
		end

		if data_containers[1]
			data = data_containers[1].tr('[]', '')
			pair = parse_key_value(data)
			@data.merge! pair
		end

		if data_containers[2]
			data = data_containers[1].tr('[]', '')
			pair = parse_key_value(data)
			@data.merge! pair
		end
	end

###################################################
# 'GP' - GPS data
###################################################
#      Info:  GPS related info
# Frequency:  Every 10 seconds
#
# Examples:
# 56.35.632 3.1.0.DEV LVST GP [0|10|UMTS] [State=Idle|NumSatellites=0]
# 56.35.767 3.1.0.DEV LVST GP [1|10|UMTS] [State=Fix|NumSatellites=8|Latitude=43.482953|Longitude=-80.537306|HAccuracy=57.69|Altitude=299.00|VAccuracy=24.00|Speed=0.00|Direction=155.30|FixTime=1415138182]
#
# Valid Keys:
#    'State'         -> [Idle|Searching|Fix|Disabled|Error|Unknown]
#    'Latitude'      -> 
#    'Longitude'     -> 
#    'HAccuracy'     -> m
#    'Altitude'      -> m
#    'VAccuracy'     -> m
#    'Speed'         -> m/s
#    'Direction'     -> degrees
#    'NumSatellites' -> number of satellites used to provide GPS fix
#    'FixTime'       -> absolute, SECONDS since (Linux) EPOCH [Jan. 1, 1970] UTC
###################################################
	def process_gp(data)
		if !data
			return false
		end
		data_containers = data.split("] [")

		data_containers.each do |container|

			if container.index('=') != nil
				data_pieces = parse_data_container(container)
				data_pieces.each do |piece|
					pair = parse_key_value(piece)
					if pair != nil
						@data.merge!(pair)
					end
				end
			else
				data_pieces = parse_data_container(container)
				@data.merge! ({"ConnectionNumber" => data_pieces[0]})
				@data.merge! ({"ConnectionGeneration" => data_pieces[1]})
				@data.merge! ({"ConnectionType" => data_pieces[2]})
			end
		end
	end
end