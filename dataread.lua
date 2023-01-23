buf = {}

i2c.setup(0,1,2,i2c.SLOW)	-- SCD41 sensor
scd40 = require"scd40"
scd40:init(0)

i2c.setup(1,1,4,i2c.SLOW)	-- indicator
ind = require"tm1637"
ind:init(1, 5, '0000')

scd40:set_automatic_self_calibration_enabled(false)
scd40:start_periodic_measurement()

function readdata()
	local co2, temp, humi = scd40:read_data()
	ind:showStr(('%4d'):format(co2))
	buf[#buf + 1] = ('%d,%d,%d'):format(co2, temp, humi)
	if #buf >= 60 then flushbuf() end
end

measurements = 0
if file.exists('data.csv') then
	local f = file.open('data.csv')
	repeat
		local line = f:readline()
		if line and line:sub(1,1) ~= '#' then
			measurements = measurements + 1
		end
	until not line
	f:close()
end

function flushbuf()
	local isNew = not file.exists('data.csv')
	local f = file.open('data.csv', 'a')
	if isNew then
		local dt = rtctime.epoch2cal(rtctime.get())
		f:writeline(('#Start: %2d.%2d.%4d %2d:%2d')
						:format(dt.day, dt.mon, dt.year, dt.hour, dt.min))
		f:writeline('#Interval: 5s')
		f:writeline('#co2ppm,temperature,humidity')
		measurements = 0
	end
	for _, t in ipairs(buf) do
			f:writeline(t)
	end
	measurements = measurements + #buf
	buf = {}
	f:close()
	if measurements >= 5760 then
			file.remove('data3.csv')
			file.rename('data2.csv', 'data3.csv')
			file.rename('data1.csv', 'data2.csv')
			file.rename('data.csv', 'data1.csv')
	end
end

rdtimer = tmr.create()
rdtimer:alarm(5000, tmr.ALARM_AUTO, readdata)
