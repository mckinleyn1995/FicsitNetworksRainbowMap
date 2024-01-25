--Variable declaration
topLeft = { 0, 0 }                    --Position is now a 2d vector (so an array of 2 numbers)
red = { 1, 0, 0, 1 }                  --Color is now an array structure of 4 numbers representing R G B A
green = { 0, 1, 0, 1 }                --Color is now an array structure of 4 numbers representing R G B A
blue = { 1, 0, 0, 1 }                 --Color is now an array structure of 4 numbers representing R G B A

colors = {
  {1, 0, 0, 1}, -- red
  {0, 1, 0, 1}, -- green
  {0, 0, 1, 1}, -- blue
  {1, 1, 0, 1}, -- yellow
  {1, 0, 1, 1}, -- magenta
  {0, 1, 1, 1}, -- cyan
  {1, 0.5, 0, 1}, -- orange
  {0.5, 0, 1, 1}, -- purple
  {0.5, 0.5, 0.5, 1}, -- grey
  {0, 0, 0, 1} -- black
}

local allPlatforms = {}
local platformIndex = 1
local currentPlatform = component.proxy(component.findComponent(classes.TrainPlatform))[platformIndex]

trackPosArray = {}

function GPU()
screen = component.proxy(component.findComponent(classes.Screen))[1]
gpu = computer.getPCIDevices(classes.GPU_T2_C)[1]
gpu:bindScreen(screen)
size = gpu:getScreenSize(screen)
ScreenX = size.x
ScreenY = size.y
print(ScreenX, ScreenY)
gpu:flush()
end

GPU()

local station = component.proxy(component.findComponent(classes.TrainPlatform))[1]

local trains = station:getTrackGraph():getTrains()
print("Found", #trains, "trains.")

local w = ScreenX
local h = ScreenY
print("Screen found", screen.nick, screen, "W x H", w, h)
local drawChar = " "

local tracks = {}
local numTracks = 0
local lastLineNum = 0 -- enable printing debug progress without slowing down too much
local skipNLines = 100 -- enable printing debug progress without slowing down too much

local function addTrack() end -- pre define for lint because addTrackConnection() references addTrack()

local function addTrackConnection(con)
 for _,c in pairs(con:getConnections()) do
  addTrack(c:getTrack())
 end
 if numTracks > lastLineNum then
   print(numTracks, "tracks found")
   lastLineNum = lastLineNum + skipNLines
 end
end

addTrack = function (track, stationName) -- now safe to add definition that references addTrackConnection()
  -- check for duplicates and only add if it doesn't already exist (tracks loop back on themsleves)
  if tracks[track.hash] == nil then
   -- cache end locations
   local cachedTrack = {}
   local c0 = track:getConnection(0)
   local c1 = track:getConnection(1)
   cachedTrack.loc0 = c0.connectorLocation
   cachedTrack.loc1 = c1.connectorLocation
   local allStations = currentPlatform:getTrackGraph():getStations()
    
   -- Print the name of the first station for the current platform
   if #allStations > 0 then
       --print("First station for platform", currentPlatform, "is", allStations[1].name) --Get the name of the first station of each network
       masterPlatform = allStations[1].name
   end
   cachedTrack.masterPlatform = masterPlatform

   tracks[track.hash] = cachedTrack
   numTracks = numTracks + 1
   -- follow each end of the track
   addTrackConnection(c0)
   addTrackConnection(c1)
  end
 end

--addTrack(station:getTrackPos()) -- can start with any track. BUGBUG sometimes this is empty at game load
::continue::
while currentPlatform do
    table.insert(allPlatforms, currentPlatform)
    local allStations = currentPlatform:getTrackGraph():getStations()
    
    -- Print the name of the first station for the current platform
    if #allStations > 0 then
        --print("First station for platform", currentPlatform, "is", allStations[1].name) --Get the name of the first station of each network
        masterPlatform = allStations[1].name
    end

    addTrack(currentPlatform:getTrackPos()) -- can start with any track. BUGBUG sometimes this is empty at game load
    --print("Done finding tracks.", numTracks,"total.")

    -- Move to the next platform
    platformIndex = platformIndex + 1
    currentPlatform = component.proxy(component.findComponent(classes.TrainPlatform))[platformIndex]
end


local min = {}
local max = {}
min.x, min.y = nil, nil -- redundant paranoid explicitness
max.x, max.y = nil, nil -- redundant paranoid explicitness

local function connectorBounds(loc)
 local x = loc.x
 local y = loc.y
 if not min.x or x < min.x then min.x = x end
 if not max.x or x > max.x then max.x = x end
 if not min.y or y < min.y then min.y = y end
 if not max.y or y > max.y then max.y = y end
end

-- find min and max world x,y bounds of all the tracks 
for _,t in pairs(tracks) do
 connectorBounds(t.loc0)
 connectorBounds(t.loc1)
end

local function actorToScreen(x, y)
-- convert world actor x,y to screen x,y
 local rangeX = max.x - min.x
 local rangeY = max.y - min.y
 x = x - min.x
 y = y - min.y
 if rangeY > rangeX then
  x = x + (rangeY- rangeX)/2
  rangeX = rangeY
 else -- rangeX >= rangeY
  y = y + (rangeX- rangeY)/2
  rangeY = rangeX
 end
 local wPad, hPad = 5, 4
 return math.floor(x / rangeX * (w-wPad)) + 2, math.floor(y / rangeY * (h-hPad)) + 2
end

local platformIndex = 1
local platformColors = {} -- new table to store colors for each platform

local function drawTrack(track)
    if track.x1 == nil then
        -- cache the converted locations
        track.x1, track.y1 = actorToScreen(track.loc0.x, track.loc0.y)
        track.x2, track.y2 = actorToScreen(track.loc1.x, track.loc1.y)
    end

    -- Create a local array for this track's points and draw them
    local trackPoints = {{track.x1, track.y1}, {track.x2, track.y2}}

    local color = colors[1] -- default color (red)
    if track.masterPlatform then
        if not platformColors[track.masterPlatform] then
            -- assign a new color to this platform
            platformColors[track.masterPlatform] = colors[platformIndex]
            platformIndex = platformIndex % #colors + 1 -- cycle through colors
        end
        color = platformColors[track.masterPlatform]
    end

    gpu:drawLines(trackPoints, 10, color)
end

-- draw all the tracks
--while true do
if ScreenX ~= 0 then
print("Safe Code")
    for _,t in pairs(tracks) do
      drawTrack(t)
    end
    gpu:flush()
end
--end
