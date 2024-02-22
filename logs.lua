LogTexts    = {}
NumLogTexts = 0


function LogDebug(text)

	ac.log(text)
	if not RunningLocally then return end
	LogTexts[NumLogTexts + 1] = {}
	LogTexts[NumLogTexts + 1][0] = os.time()
	LogTexts[NumLogTexts + 1][1] = text
	NumLogTexts = NumLogTexts + 1

end

function LogDebugFormat(text, ...)

	LogDebug(string.format(text, ...))

end


local _lastPeriodicLogTimes = {}

function LogDebugPeriodically(key, repeatTime, text)

	if _lastPeriodicLogTimes[key] and os.time() < _lastPeriodicLogTimes[key] + repeatTime then
		return false
	end
	_lastPeriodicLogTimes[key] = os.time()

	LogDebug(text)
	return true

end

function LogDebugFormatPeriodically(key, repeatTime, text, ...)

	return LogDebugPeriodically(key, repeatTime, string.format(text, ...))

end


function LogDebugNotice(text)
	for i=1,5 do
		LogDebug("*** " .. text .. " ***")
	end
end


function LogWarning(text)

	ac.warn("WARNING: " .. text)
	if not RunningLocally then return end
	LogTexts[NumLogTexts + 1] = {}
	LogTexts[NumLogTexts + 1][0] = os.time()
	LogTexts[NumLogTexts + 1][1] = "WARNING: " .. text
	NumLogTexts = NumLogTexts + 1

end

function LogWarningFormat(text, ...)

	LogWarning(string.format(text, ...))

end


function LogError(text)

	ac.error("ERROR: " .. text)
	if not RunningLocally then return end
	LogTexts[NumLogTexts + 1] = {}
	LogTexts[NumLogTexts + 1][0] = os.time()
	LogTexts[NumLogTexts + 1][1] = "ERROR: " .. text
	NumLogTexts = NumLogTexts + 1

end

function LogErrorFormat(text, ...)

	LogError(string.format(text, ...))

end


function LogsRender()
	
	if NumLogTexts > 0 then
		for i=1,NumLogTexts do
			if string.find(LogTexts[i][1], "ERROR:") then
				ui.dwriteText(tostring(LogTexts[i][0]) .. " | " .. LogTexts[i][1], 20, rgbm(1, 0.3, 0.3, 1))
			else
				ui.dwriteText(tostring(LogTexts[i][0]) .. " | " .. LogTexts[i][1], 20)
			end
		end
	end

end
