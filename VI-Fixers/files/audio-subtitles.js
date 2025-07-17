const audioCache = new Map();
const activeAudio = new Map();
const activeSubtitles = new Map();
const preloadedAudio = new Map();

const subtitleContainer = document.getElementById('subtitle-container');
const subtitleSpeaker = document.getElementById('subtitle-speaker');
const subtitleText = document.getElementById('subtitle-text');
const subtitleProgress = document.getElementById('subtitle-progress');

function preloadAudio(fileName) {
    return new Promise((resolve, reject) => {
        if (preloadedAudio.has(fileName)) {
            resolve(preloadedAudio.get(fileName));
            return;
        }
        
        const audio = new Audio(`./sounds/${fileName}`);
        audio.preload = 'auto';
        
        const loadHandler = () => {
            audio.removeEventListener('canplaythrough', loadHandler);
            preloadedAudio.set(fileName, audio);
            resolve(audio);
        };
        
        const errorHandler = (err) => {
            audio.removeEventListener('error', errorHandler);
            console.error(`Error loading audio ${fileName}:`, err);
            reject(err);
        };
        
        audio.addEventListener('canplaythrough', loadHandler);
        audio.addEventListener('error', errorHandler);
        
        audio.load();
    });
}

function getAudio(file) {
    if (audioCache.has(file)) {
        const original = audioCache.get(file);
        const clone = new Audio();
        clone.src = original.src;
        return clone;
    }
    
    const audio = new Audio(`./sounds/${file}`);
    
    audioCache.set(file, audio);
    return audio;
}

function updateSubtitleProgress(id) {
    if (!activeSubtitles.has(id)) return;
    
    const subtitle = activeSubtitles.get(id);
    
    if (subtitle.paused) return;
    
    const now = Date.now();
    
    if (now >= subtitle.endTime) {
        hideSubtitle(id);
        return;
    }
    
    subtitle.elapsed = now - subtitle.startTime;
    const progress = Math.min(100, (subtitle.elapsed / subtitle.duration) * 100);
    subtitle.progressElement.style.width = `${progress}%`;
}

function showSubtitle(id, text, speaker, duration) {
    if (!subtitleContainer || !subtitleText || !subtitleSpeaker || !subtitleProgress) return;
    
    for (const [existingId, subtitle] of activeSubtitles.entries()) {
        if (subtitle.updateInterval) {
            clearInterval(subtitle.updateInterval);
        }
        subtitle.element.classList.add('hidden');
        subtitle.progressElement.style.width = '0%';
        activeSubtitles.delete(existingId);
    }
    
    subtitleSpeaker.textContent = speaker || '';
    subtitleText.textContent = text || '';
        
    subtitleContainer.classList.remove('hidden');
    subtitleContainer.style.animation = "slide-up 0.5s ease-in forwards";
    
    const startTime = Date.now();
    const endTime = startTime + (duration || 3000);
    const currentTimeStamp = startTime;
    
    activeSubtitles.set(id, {
        element: subtitleContainer,
        progressElement: subtitleProgress,
        startTime: startTime,
        endTime: endTime,
        duration: duration || 3000,
        elapsed: 0,
        paused: false,
        timeStampId: currentTimeStamp,
        updateInterval: setInterval(() => updateSubtitleProgress(id), 50)
    });
    
    return currentTimeStamp;
}

function hideSubtitle(id) {
    if (!activeSubtitles.has(id)) return;
    
    const subtitle = activeSubtitles.get(id);
    const timeStampId = subtitle.timeStampId;
    
    if (subtitle.updateInterval) {
        clearInterval(subtitle.updateInterval);
    }
    
    const element = subtitle.element;
    const progressElement = subtitle.progressElement;
    
    activeSubtitles.delete(id);
    element.style.animation = "slide-down 0.7s ease-out forwards";
    
    setTimeout(() => {
        let shouldHide = true;
        activeSubtitles.forEach(sub => {
            if (sub.timeStampId > timeStampId) {
                shouldHide = false;
            }
        });
        
        if (shouldHide) {
            element.classList.add('hidden');
            element.style.animation = "";
            progressElement.style.width = '0%';
        }
    }, 700);
}

function pauseSubtitle(id) {
    if (!activeSubtitles.has(id)) return;
    
    const subtitle = activeSubtitles.get(id);
    
    const now = Date.now();
    subtitle.elapsed = now - subtitle.startTime;
    
    subtitle.paused = true;
    subtitle.element.classList.add('hidden');
}

function resumeSubtitle(id) {
    if (!activeSubtitles.has(id)) return;
    
    const subtitle = activeSubtitles.get(id);
    
    if (!subtitle.paused) return;
    
    const now = Date.now();
    subtitle.startTime = now - subtitle.elapsed;
    subtitle.endTime = subtitle.startTime + subtitle.duration;
    
    subtitle.paused = false;
    subtitle.element.classList.remove('hidden');
}

function updateSubtitleVisibility(id, visible) {
    if (visible) {
        resumeSubtitle(id);
    } else {
        pauseSubtitle(id);
    }
}

function hideAllSubtitles() {
    activeSubtitles.forEach((_, id) => {
        hideSubtitle(id);
    });
}

window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch (data.type) {
        case 'playAudio':
            playAudio(data);
        break;

        case 'pauseAudio':
            pauseAudio(data.id);
        break;
            
        case 'resumeAudio':
            resumeAudio(data.id, data.startTime);
        break;
            
        case 'stopAudio':
            stopAudio(data.id);
        break;
            
        case 'setVolume':
            setVolume(data.id, data.volume);
        break;
            
        case 'showSubtitle':
            showSubtitle(data.id, data.text, data.speaker, data.duration);
        break;
            
        case 'hideSubtitle':
            hideSubtitle(data.id);
        break;
            
        case 'hideAllSubtitles':
            hideAllSubtitles();
        break;
            
        case 'updateSubtitleVisibility':
            updateSubtitleVisibility(data.id, data.visible);
        break;
            
        case 'preloadAudio':
            preloadAudio(data.file).catch(err => console.error(`Preload failed for ${data.file}:`, err));
        break;
    }
});

function playAudio(data) {
    const { id, file, volume, loop, startTime, subtitle, enableSubtitles, is3D, initialVolume } = data;
    
    if (activeAudio.has(id)) {
        stopAudio(id);
    }
    
    preloadAudio(file).then(originalAudio => {
        const audio = new Audio();
        audio.src = originalAudio.src;
        
        const audioContext = new window.AudioContext;
        const source = audioContext.createMediaElementSource(audio);
        const gainNode = audioContext.createGain();
        
        source.connect(gainNode);
        gainNode.connect(audioContext.destination);
        
        gainNode.gain.value = 0;
        audio.volume = 1;
        audio.loop = loop || false;
        let lastPosition = 0;
        
        const positionInterval = setInterval(() => {
            if (!audio.paused && !isNaN(audio.currentTime)) {
                if (Math.abs(audio.currentTime - lastPosition) > 0.2) {
                    lastPosition = audio.currentTime;
                    fetch(`https://${GetParentResourceName()}/audioPosUpdate`, {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json; charset=UTF-8',
                        },
                        body: JSON.stringify({
                            id: id,
                            position: audio.currentTime
                        })
                    }).catch(err => {
                        console.error('Failed to report audio position update:', err);
                    });
                }
            }
        }, 500);
        
        audio.onended = function() {
            if (!audio.loop) {
                clearInterval(positionInterval);
                
                fetch(`https://${GetParentResourceName()}/audioEnded`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json; charset=UTF-8',
                    },
                    body: JSON.stringify({
                        id: id
                    })
                }).catch(err => {
                    console.error('Failed to report audio ended:', err);
                });
                
                activeAudio.delete(id);
            }
        };
        
        activeAudio.set(id, {
            element: audio,
            positionInterval: positionInterval,
            file: file,
            enableSubtitles: enableSubtitles !== false,
            startPlayTime: Date.now(),
            context: audioContext,
            gainNode: gainNode,
            is3D: is3D || false
        });
        
        if (startTime && !isNaN(startTime)) {
            try {
                audio.currentTime = startTime;
            } catch (e) {
                console.error('Failed to set audio start time:', e);
            }
        }
        
        if (enableSubtitles !== false && subtitle && subtitle.text) {
            showSubtitle(
                id, 
                subtitle.text, 
                subtitle.speaker, 
                subtitle.duration || (audio.duration * 1000) || 5000
            );
        }
        
        const playPromise = audio.play();
        
        if (playPromise !== undefined) {
            playPromise.then(() => {
                let targetVolume = volume || 0;
                
                if (is3D && initialVolume !== undefined) {
                    targetVolume = initialVolume;
                }
                
                gainNode.gain.setValueAtTime(0, audioContext.currentTime);
                gainNode.gain.linearRampToValueAtTime(targetVolume, audioContext.currentTime + 0.2);
            }).catch(err => {
                console.error('Audio playback failed:', err);
                fetch(`https://${GetParentResourceName()}/audioEnded`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json; charset=UTF-8',
                    },
                    body: JSON.stringify({
                        id: id
                    })
                }).catch(innerErr => {
                    console.error('Failed to report audio ended after playback failure:', innerErr);
                });
            });
        }
    }).catch(err => {
        console.error(`Failed to play audio ${file}:`, err);
        fetch(`https://${GetParentResourceName()}/audioEnded`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify({
                id: id
            })
        }).catch(innerErr => {
            console.error('Failed to report audio ended after preload failure:', innerErr);
        });
    });
}

function pauseAudio(id) {
    if (activeAudio.has(id)) {
        const audioData = activeAudio.get(id);
        if (audioData && audioData.element) {
            audioData.element.pause();
            
            if (audioData.enableSubtitles !== false && activeSubtitles.has(id)) {
                pauseSubtitle(id);
            }
        }
    }
}

function resumeAudio(id, startTime) {
    if (activeAudio.has(id)) {
        const audioData = activeAudio.get(id);
        if (audioData && audioData.element) {
            if (audioData.element.readyState < 2) {
                console.error(`Audio ${id} not ready to play, state: ${audioData.element.readyState}`);
                fetch(`https://${GetParentResourceName()}/audioEnded`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json; charset=UTF-8',
                    },
                    body: JSON.stringify({
                        id: id
                    })
                }).catch(err => {
                    console.error('Failed to report audio ended after resume failure:', err);
                });
                return;
            }
            
            if (!audioData.element.paused) {
                console.log(`Audio ${id} is already playing, not resuming again`);
                return;
            }
            
            if (startTime !== undefined && !isNaN(startTime)) {
                try {
                    audioData.element.currentTime = startTime;
                } catch (e) {
                    console.error('Failed to set resume time:', e);
                }
            }
            
            if (audioData.enableSubtitles !== false && activeSubtitles.has(id)) {
                resumeSubtitle(id);
            }
            
            const playPromise = audioData.element.play();
            
            if (playPromise !== undefined) {
                playPromise.catch(error => {
                    console.error('Audio resume failed:', error);
                    fetch(`https://${GetParentResourceName()}/audioEnded`, {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json; charset=UTF-8',
                        },
                        body: JSON.stringify({
                            id: id
                        })
                    }).catch(err => {
                        console.error('Failed to report audio ended after resume promise failure:', err);
                    });
                });
            }
        }
    }
}

function stopAudio(id) {
    if (activeAudio.has(id)) {
        const audioData = activeAudio.get(id);
        
        if (audioData.element) {
            audioData.element.pause();
            audioData.element.currentTime = 0;
            audioData.element.onended = null;
        }
        
        if (audioData.positionInterval) {
            clearInterval(audioData.positionInterval);
        }
        
        if (audioData.context && audioData.context.state !== 'closed') {
            try {
                if (audioData.gainNode) {
                    const now = audioData.context.currentTime;
                    audioData.gainNode.gain.setValueAtTime(audioData.gainNode.gain.value, now);
                    audioData.gainNode.gain.linearRampToValueAtTime(0, now + 0.1);
                    
                    setTimeout(() => {
                        try {
                            audioData.context.close();
                        } catch (e) {
                            console.error('Error closing audio context:', e);
                        }
                    }, 150);
                } else {
                    audioData.context.close();
                }
            } catch (e) {
                console.error('Error during audio context cleanup:', e);
            }
        }
        
        activeAudio.delete(id);
        
        if (activeSubtitles.has(id)) {
            hideSubtitle(id);
        }
    }
}

function setVolume(id, volume) {
    if (activeAudio.has(id)) {
        const audioData = activeAudio.get(id);
        if (audioData && audioData.gainNode) {
            const ctx = audioData.context;
            audioData.gainNode.gain.cancelScheduledValues(ctx.currentTime);
            audioData.gainNode.gain.setValueAtTime(audioData.gainNode.gain.value, ctx.currentTime);
            audioData.gainNode.gain.linearRampToValueAtTime(Math.max(0, Math.min(1, volume)), ctx.currentTime + 0.1);
        } else if (audioData && audioData.element) {
            audioData.element.volume = Math.max(0, Math.min(1, volume));
        }
    }
}

function initializeSubtitleSystem() {
    document.addEventListener('DOMContentLoaded', () => {
        const style = document.createElement('style');
        document.head.appendChild(style);
    });
}

initializeSubtitleSystem();