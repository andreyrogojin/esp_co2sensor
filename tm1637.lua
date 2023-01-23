local zn = {
  ['0'] = 0xfc,
  ['1'] = 0x60,
  ['2'] = 0xda,
  ['3'] = 0xf2,
  ['4'] = 0x66,
  ['5'] = 0xb6,
  ['6'] = 0xbe,
  ['7'] = 0xe0,
  ['8'] = 0xfe,
  ['9'] = 0xf6,
  ['-'] = 0x02,
  ['a'] = 0xee,
  ['b'] = 0x3e,
  ['c'] = 0x9c,
  ['d'] = 0x7a,
  ['e'] = 0x9e,
  ['f'] = 0x8e,
  ['g'] = 0xbc,
  ['h'] = 0x2e,
  ['i'] = 0x20,
  ['j'] = 0x30,
  ['k'] = 0x0e,
  ['l'] = 0x1c,
  ['n'] = 0xec,
  ['o'] = 0x3a,
  ['p'] = 0xce,
  ['q'] = 0xe6,
  ['r'] = 0x8c,
  ['s'] = 0xb6,
  ['t'] = 0x72,
  ['u'] = 0x38,
  ['y'] = 0x76
}

local lumCodes = { [0] = 0x01, 0x11, 0x91, 0x51, 0xd1, 0x31, 0xb1, 0x71, 0xf1 }
local posCodes = { 0x03,0x83,0x43,0xc3,0x23,0xa3 }
local keyCodesR = { [0xef]=1, [0x6f]=2, [0xaf]=3, [0x2f]=4, [0xcf]=5, [0x4f]=6, [0x8f]=7, [0x0f]=8,
             [0xf7]=9, [0x77]=10, [0xb7]=11, [0x37]=12, [0xd7]=13, [0x57]=14, [0x97]=15, [0x17]=16 }

local function setLuminance(self, lum)
  lum = lum or 3
  i2c.start(self.id)
  i2c.write(self.id,0x02)
  i2c.stop(self.id)
  i2c.start(self.id)
  i2c.write(self.id,lumCodes[lum])
  i2c.stop(self.id)
end

local function showDCodes(self, pos, len)
  local p = pos or 1
  local l = len or 1
  i2c.start(self.id)
  i2c.write(self.id,0x02)
  i2c.stop(self.id)
  i2c.start(self.id)
  i2c.write(self.id, posCodes[p])
  for i = p, p+l-1 do
    i2c.write(self.id, self.dCodes[i])
  end
  i2c.stop(self.id)
end

local function showStr(self, str, pos)
  local len = str:len()
  local p = pos or 1
  if len + p > 7 then len = 7 - p end
  for i = 1, len do
    self.dCodes[i+p-1] = zn[str:sub(i,i)] or 0
  end
  showDCodes(self, pos, len)
end

local function colon(self, show) -- 1 show, 0 hide, 2 toggle
  if self.dCodes[2] % 2 == 1 then
    if show == 0 or show == 2 then
      self.dCodes[2] = self.dCodes[2] - 1
    end
  else
    if show == 1 or show == 2 then
      self.dCodes[2] = self.dCodes[2] + 1
    end
  end
  showDCodes(self,2)
end

local function readKeys(self)
  i2c.start(self.id)
  i2c.write(self.id,0x42)
  local keyCode = i2c.read(self.id,1)
  i2c.stop(self.id)
  return(keyCodesR[keyCode:byte()])
end

local function init(self, i2c_id, lum, str)
  self.id = i2c_id
  self:setLuminance(lum)
  self:showStr(str or "      ")
end

return({
  id = 0,
  dCodes = { 0,0,0,0,0,0 },
  setLuminance = setLuminance,
  showStr = showStr,
  colon = colon,
  readKeys = readKeys,
  init = init
})

