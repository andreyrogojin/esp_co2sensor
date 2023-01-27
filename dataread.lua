buf = {}

i2c.setup(0,1,2,i2c.SLOW)	-- SCD41 sensor
scd40 = require"scd40"
scd40:init(0)

i2c.setup(1,1,4,i2c.SLOW)	-- indicator
ind = require"tm1637"
ind:init(1, 5, '0000')

scd40:set_automatic_self_calibration_enabled(false)
scd40:start_periodic_measurement()

measurements = 0
function readdata()
	local co2, temp, humi = scd40:read_data()
	ind:showStr(('%4d'):format(co2))
	
	if datafile then
		if measurements == 0 then
			local dt = rtctime.epoch2cal(rtctime.get())
			datafile:writeline(('#Start: %2d.%2d.%4d %2d:%2d')
						:format(dt.day, dt.mon, dt.year, dt.hour, dt.min))
			datafile:writeline('#Interval: 5s')
			datafile:writeline('co2ppm,temperature,humidity')
		end
		datafile:writeline(('%d,%d,%d'):format(co2, temp, humi))
		measurements = measurements + 1
		if datasocket then
			datasocket:send(('%d,%d,%d\n'):format(co2, temp, humi))
		end
		if measurements > 720 then
			datafile:close()
			datafile = nil
			datasocket:close()
			datasocket = nil
			measurements = 0
		end
	end
	if datasocket then
		datasocket:send(('%d,%d,%d'):format(co2, temp, humi))
	end
end

rdtimer = tmr.create()
rdtimer:alarm(5000, tmr.ALARM_AUTO, readdata)
