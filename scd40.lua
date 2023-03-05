local function crc8(...)	-- compute crc8
	local arg = {...}
    local crc = 0xff
    for _,v in ipairs(arg) do
        crc = bit.bxor(crc, v)
        for i = 8,1,-1 do
            if (0 ~= bit.band(crc, 0x80)) then
                crc = bit.bxor(bit.band(bit.lshift(crc, 1), 0xff), 0x31)
            else
                crc = bit.band(bit.lshift(crc, 1), 0xff)
            end
        end
    end
    return crc
end

local function check_crc(res)	-- 3-byte string.  Check 2-byte crc == byte3
    return crc8(res:byte(1,2)) == res:byte(3)
end

local function scd_write(self, cmd1, cmd2, data1, data2)
	i2c.start(self.id)
	i2c.address(self.id, 0x62, i2c.TRANSMITTER)
	i2c.write(self.id, cmd1, cmd2, data1, data2, crc8(data1, data2))
	i2c.stop(self.id)
end

local function scd_cmd(self, cmd1, cmd2)
	i2c.start(self.id)
	i2c.address(self.id, 0x62, i2c.TRANSMITTER)
	i2c.write(self.id, cmd1, cmd2)
	i2c.stop(self.id)
end

local function scd_read(self, cmd1, cmd2, count)
	local res
	i2c.start(self.id)
	i2c.address(self.id, 0x62, i2c.TRANSMITTER)
	i2c.write(self.id, cmd1, cmd2)
	i2c.start(self.id)
	i2c.address(self.id, 0x62, i2c.RECEIVER)
	res = i2c.read(self.id, count)
	i2c.stop(self.id)
	return res
end

local function scd_write_read(self, cmd1, cmd2, data1, data2, count)
	i2c.start(self.id)
	i2c.address(self.id, 0x62, i2c.TRANSMITTER)
	i2c.write(self.id, cmd1, cmd2, data1, data2, crc8(data1, data2))
	tmr.create():alarm(400, tmr.ALARM_SINGLE,
		function()
			local res
			i2c.start(self.id)
			i2c.address(self.id, 0x62, i2c.RECEIVER)
			res = i2c.read(self.id, count)
			i2c.stop(self.id)
			cal_correction = struct.unpack('>I2', res) - 0x8000
		end)
end

local function start_periodic_measurement(self)
	scd_cmd(self, 0x21,0xb1)
end

local function stop_periodic_measurement(self)
	scd_cmd(self, 0x3f,0x86)
end

local function get_data_ready_status(self)
	local res
	res = scd_read(self, 0xe4,0xb8, 3)
	return bit.band(res:byte(1), 0x03) ~= 0 or res:byte(2) ~= 0
end

local function read_measurement(self)
	local cnt = 0
	while not get_data_ready_status(self) do
		if cnt > 5000 then return '\0\0\0\0\0\0\0\0\0' end
		tmr.delay(1000)
		cnt = cnt + 1
	end
	return scd_read(self, 0xec,0x05, 9)
end

local function perform_forced_recalibration(self, value)
	value = value or 400
	start_periodic_measurement(self)
	tmr.create():alarm(3*60*1000, tmr.ALARM_SINGLE,
		function()
			stop_periodic_measurement(self)
			tmr.create():alarm(500, tmr.ALARM_SINGLE,
				function()
					local t = {struct.pack('>I2', value):byte(1,2)}
					table.insert(t, 3)
					scd_write_read(self,0x36,0x2f, unpack(t))
				end)
		end)
end

local function set_automatic_self_calibration_enabled(self, status)
	scd_write(self, 0x24,0x16, 0, status and 1 or 0)
end

local function read_data(self)
    local res
    local co2ppm = 9999
    local t = 9999
	local t_dec = 9
    local rh = 9999
	res = read_measurement(self)
    if check_crc(res:sub(1,3)) then
    	co2ppm = struct.unpack('>I2', res)
    end
	if check_crc(res:sub(4,6)) then
        local t10 = struct.unpack('>I2', res, 4) * 1750 / 0xffff - 450
		t = t10 / 10
		t_dec = t10 % 10
    end
    if check_crc(res:sub(7,9)) then
        rh = struct.unpack('>I2', res, 7) * 100 / 0xffff
    end
	return co2ppm, t, rh, t_dec
end

local function init(self, i2c_id)
	self.id = i2c_id
end

return {
	id = 0,
	crc8 = crc8,
	start_periodic_measurement = start_periodic_measurement,
	stop_periodic_measurement = stop_periodic_measurement,
	read_measurement = read_measurement,
	set_automatic_self_calibration_enabled = set_automatic_self_calibration_enabled,
	perform_forced_recalibration = perform_forced_recalibration,
	get_data_ready_status = get_data_ready_status,
	read_data = read_data,
	init = init,
}
