module WorkingHours
  module Computation

    def config
      WorkingHours::Config.precompiled
    end

    def add_days origin, days
      time = origin.in_time_zone(config[:time_zone])
      while days > 0
        time += 1.day
        days -= 1 if working_day?(time)
      end
      while days < 0
        time -= 1.day
        days += 1 if working_day?(time)
      end
      convert_to_original_format time, origin
    end

    def add_hours origin, hours
      add_minutes origin, hours*60
    end

    def add_minutes origin, minutes
      add_seconds origin, minutes*60
    end

    def add_seconds origin, seconds
      time = origin.in_time_zone(config[:time_zone])
      while seconds > 0
        # roll to next business period
        time = advance_to_working_time(time)
        # look at working ranges
        time_in_day = time.seconds_since_midnight
        config[:working_hours][time.wday].each do |from, to|
          if time_in_day >= from and time_in_day < to
            # take all we can
            take = [to - time_in_day, seconds].min
            # advance time
            time += take
            # decrease seconds
            seconds -= take
          end
        end
      end
      convert_to_original_format time, origin
    end

    def advance_to_working_time time
      return time if in_working_hours? time
      loop do
        # skip holidays and weekends
        while not working_day?(time)
          time = (time + 1.day).beginning_of_day
        end
        # find first working range after time
        time_in_day = time.seconds_since_midnight
        (Config.precompiled[:working_hours][time.wday] || {}).each do |from, to|
          return time + (from - time_in_day) if from >= time_in_day
        end
        # if none is found, go to next day and loop
        time = (time + 1.day).beginning_of_day
      end
    end

    def working_day? time
      Config.precompiled[:working_hours][time.wday].present? and not Config.precompiled[:holidays].include?(time.to_date)
    end

    def in_working_hours? time
      return false if not working_day?(time)
      time_in_day = time.seconds_since_midnight
      Config.precompiled[:working_hours][time.wday].each do |from, to|
        return true if time_in_day >= from and time_in_day < to
      end
      false
    end

    def convert_to_original_format time, original
      case original
      when Date then time.to_date
      when DateTime then time.to_datetime
      else time
      end
    end

  end
end