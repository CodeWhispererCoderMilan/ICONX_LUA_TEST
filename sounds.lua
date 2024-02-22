local soundPath = 'https://iconx.world/traffic/sounds'

local _goldSoundFile = soundPath .. "/gold.mp3"

local _goalsMediaPlayer = ui.MediaPlayer()


function script.playGoldGoalSound(volume)
	if SoundsOn then
		script.playSound(_goalsMediaPlayer, _goldSoundFile, volume)
	end
end


function script.playSound(mediaPlayer, soundFileName, volume)

	if not soundFileName then return false end
	if not mediaPlayer then return false end
	if not volume then volume = 0.25 end

	if not SoundsOn then
		-- mediaPlayer:setVolume(0)
		-- mediaPlayer:pause()
		return
	end

	-- LogDebug("Playing: " .. soundFileName)

	mediaPlayer:setSource(soundFileName)
	mediaPlayer:setVolume(volume)
	mediaPlayer:play()
	return true

end
