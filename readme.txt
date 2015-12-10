Stream Health Parser | Notes

To run:
just run parsestreamhealth.rb <file name>

If no file name is included, it will ask for one.
Currently handles one file, but that can be adjusted.

Algorithm

Identify
- Frame loss events
- Frame size change events
Pre-filter
- Coalesce events of the same type that are <5 seconds apart 
  < Saving the timestamp for each type of event, and ignoring events that follow within 5 seconds, then saving a new timestamp when an event outside of 5 seconds is found >
- Filter out events in the first 30 seconds
  < Saving timestamp from Action=APP.STARTUP event, and ignoring events for the first 30 seconds thereafter >
- Filter out streams shorter than 1 minute
  < Not technically being done, but can easily be done in the parsestreamhealth.rb file. Just check the total_time attribue of the stream object >

Calculate metric from filtered events
- Count # of frame loss events
  < Counting number of events that have the category "EN" and whose "NumberOfLostVideoFrames" isn't 0. Not adding up the number of lost frames >
  - FrameLossMetric = (0.5)# of frame loss events

- Calculate peak frame size change events per second (expected to be [0,1])
  < Line 105 increments a counter every time the frame size changes and then line 130 calculates the changes/second by dividing the number of changes by the total number of seconds >
  - FrameSizeChangeMetric = 1.0 - (change events per second)

- Calculate amount of time at each frame size
  - FrameSizeMetric = k*(total stream duration)/[16*(time at 180p)+ 8*(time at 240p) + (time at all other frame sizes)]
  - Where
    < MaxConnectionBitrate is being determined by a "CX" live stat with the greatest "Received BPS (smoothed)" attribute. Can be easily edited on lines 77 and 78 >
    k == 16 if MaxConnectionBitrate <= 500000
    k == 8 if 500000 <= MaxConnectionBitrate < 1100000
    k == 1 otherwise

< Not really sure what MIN() is, appears to be a function, but I'm not sure. See lines 137 and 138 for determing percentage of stream health >
- OverallHealthMetric = MIN(FrameLossMetric,FrameSizeChangeMetric, FrameSizeMetric)
  - Good: 90% <= OverallHealthMetric
  - Marginal: 25% <= OverallHealthMetric < 90%
  - Poor: 0% <= OverallHealthMetric < 25%