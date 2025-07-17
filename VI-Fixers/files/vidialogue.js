const dialogueContainer = document.getElementById('vidialogue-container');
const promptText = document.getElementById('prompt-text');
const choiceList = document.getElementById('choice-list');
const choiceTimer = document.getElementById('choice-timer');
const activeChoices = new Map();
const iconMap = {
    'question': 'fa-solid fa-circle-question',
    'briefcase': 'fa-solid fa-briefcase',
    'angry': 'fa-solid fa-face-angry',
    'money': 'fa-solid fa-coins',
    'gun': 'fa-solid fa-gun',
    'heart': 'fa-solid fa-heart',
    'info': 'fa-solid fa-sitemap',
    'handshake': 'fa-solid fa-handshake',
    'decline': 'fa-solid fa-sack-xmark',
    'default': 'fa-solid fa-circle-question',
};
let currentFocusIndex = 0;

window.addEventListener('message', function(event) {
    const data = event.data;
    
    if (data.type === 'showDialogueChoices') {
        showChoices(data);
    } else if (data.type === 'hideDialogueChoices') {
        hideChoices(data.id);
    } else if (data.type === 'getChoiceBranchName') {
        const choiceData = activeChoices.get(data.id);
        if (choiceData && choiceData.choices[data.index - 1]) {
            sendChoiceSelection(data.id, data.index, choiceData.choices[data.index - 1].branchName);
        }
    }
});

function getIconClass(iconName) {
    return iconMap[iconName] || iconMap['default'];
}

function showChoices(data) {
    const { id, promptText: prompt, choices, timeout } = data;
    activeChoices.set(id, {
        choices: choices,
        startTime: Date.now(),
        timeout: timeout
    });
    
    promptText.textContent = prompt || 'What\'s your response?';
    
    choiceList.innerHTML = '';
    currentFocusIndex = 0;
        
    choices.forEach((choice, index) => {
        const li = document.createElement('li');
        li.className = 'choice-item';
        li.dataset.index = index + 1;
        li.dataset.id = id;
        li.dataset.branchName = choice.branchName;
        
        const iconSpan = document.createElement('span');
        iconSpan.className = 'choice-icon';
        
        const iconElement = document.createElement('i');
        iconElement.className = getIconClass(choice.icon);
        iconSpan.appendChild(iconElement);
        
        const textSpan = document.createElement('span');
        textSpan.className = 'choice-text';
        textSpan.textContent = choice.text;
        
        li.appendChild(iconSpan);
        li.appendChild(textSpan);
        
        li.addEventListener('click', function() {
            selectChoice(id, index + 1, choice.branchName);
        });
        
        choiceList.appendChild(li);
    });
    
    dialogueContainer.classList.remove('slide-out');
    dialogueContainer.classList.add('visible');
    
    updateFocus(0);
    if (timeout) {
        choiceTimer.style.animation = 'none';
        choiceTimer.offsetHeight;
        choiceTimer.style.display = 'block';
        
        choiceTimer.style.animation = `timerCountdown ${timeout/1000}s linear forwards`;
    } else {
        choiceTimer.style.display = 'none';
    }
}

function hideChoices(id) {
    if (!id || activeChoices.has(id)) {
        dialogueContainer.classList.add('slide-out');
        
        setTimeout(() => {
            dialogueContainer.classList.remove('visible', 'slide-out');
            choiceTimer.style.animation = '';
            activeChoices.delete(id);
        }, 500);
    }
}

function selectChoice(id, index, branchName) {
    const choices = choiceList.querySelectorAll('.choice-item');
    
    choices.forEach(choice => {
        choice.classList.remove('selected');
        
        const existingSignal = choice.querySelector('.choice-signal');
        if (existingSignal) {
            choice.removeChild(existingSignal);
        }
    });
    
    sendChoiceSelection(id, index, branchName);
    
    setTimeout(() => {
        hideChoices(id);
    }, 300);
}

function sendChoiceSelection(id, index, branchName) {
    fetch(`https://${GetParentResourceName()}/dialogueChoiceSelected`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            id: id,
            index: index,
            branchName: branchName
        })
    });
}

function getChoiceBranchName(id, index) {
    const choiceData = activeChoices.get(id);
    if (choiceData && choiceData.choices[index - 1]) {
        return choiceData.choices[index - 1].branchName;
    }
    return null;
}

function updateFocus(newIndex) {
    const enabledChoices = Array.from(choiceList.querySelectorAll('.choice-item'));

    if (enabledChoices.length === 0) return;

    currentFocusIndex = (newIndex + enabledChoices.length) % enabledChoices.length;

    enabledChoices.forEach(choice => {
        choice.classList.remove('focused');

        const existingSignal = choice.querySelector('.choice-signal');
        if (existingSignal) {
            choice.removeChild(existingSignal);
        }
    });

    const focusedChoice = enabledChoices[currentFocusIndex];
    focusedChoice.classList.add('focused');

    const signalElement = document.createElement('div');
    signalElement.className = 'choice-signal';
    signalElement.innerHTML = `
        <div class="signal-bar"></div>
        <div class="signal-bar"></div>
        <div class="signal-bar"></div>
    `;
    focusedChoice.appendChild(signalElement);

    focusedChoice.scrollIntoView({ 
        behavior: 'smooth', 
        block: 'nearest' 
    });
}

document.addEventListener('keydown', (event) => {
    if (!dialogueContainer.classList.contains('visible')) return;
    const activeId = Array.from(activeChoices.keys())[0];
    if (!activeId) return;
    
    const enabledChoices = Array.from(choiceList.querySelectorAll('.choice-item'));
    
    switch (event.key) {
        case 'ArrowUp':
            updateFocus(currentFocusIndex - 1);
            event.preventDefault();
        break;
            
        case 'ArrowDown':
            updateFocus(currentFocusIndex + 1);
            event.preventDefault();
        break;
            
        case 'Enter':
            if (enabledChoices.length > 0) {
                const selectedChoice = enabledChoices[currentFocusIndex];
                const index = parseInt(selectedChoice.dataset.index);
                const branchName = selectedChoice.dataset.branchName;
                selectChoice(activeId, index, branchName);
            }
            event.preventDefault();
        break;
    }
});

function initializeKeyboardNavigation() {
    updateFocus(0);
}