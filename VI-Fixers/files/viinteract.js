let currentInteractions = [];
let interactions = [];
let isVisible = false;
let activeInteractionIndex = 0;

document.addEventListener('DOMContentLoaded', function() {
    if (!document.getElementById('viinteract-container')) {
        const container = document.createElement('div');
        container.id = 'viinteract-container';
        document.body.appendChild(container);
    }
    
    window.addEventListener('message', function(event) {
        const data = event.data;
        
        switch (data.action) {
            case 'showInteraction':
                showInteraction(data.interactions);
            break;
            case 'hideInteraction':
                hideInteraction();
            break;
            case 'triggerKeyAnimation':
                triggerKeyAnimation(data.key);
            break;
            case 'interactionOptionSelected':
                updateSelectedOption(data.index, data.key);
            break;
        }
    });
    
    document.addEventListener('keydown', function(event) {
        if (event.key === 'Escape') {
            hideInteraction();
        }
    });
});

function showInteraction(interactions) {
    const container = document.getElementById('viinteract-container');
    if (!container) {
        console.error('[ERROR] Could not find container #viinteract-container');
        return;
    }

    currentInteractions = interactions;
    activeInteractionIndex = 0;

    container.innerHTML = '';

    if (!interactions || interactions.length === 0) {
        console.warn('[WARN] No interactions to show, calling hideInteraction()');
        hideInteraction();
        return;
    }

    interactions.forEach((interaction, index) => {
        try {
            const promptElement = createInteractionElement(interaction, index);
            if (!promptElement) {
                console.warn(`[WARN] createInteractionElement returned null for index ${index}`);
            } else {
                container.appendChild(promptElement);
            }
        } catch (err) {
            console.error(`[ERROR] Failed to create/append interaction at index ${index}:`, err);
        }
    });

    container.classList.add('visible');
    isVisible = true;

    sendToGame('interactionVisibilityChanged', { visible: true });
}

function createInteractionElement(interaction, index) {
    if (!interaction || typeof interaction !== 'object') {
        return null;
    }

    const promptElement = document.createElement('div');
    promptElement.className = 'interact-prompt';
    if (currentInteractions.length > 1) {
        promptElement.classList.add('interact-option');
    }
    promptElement.dataset.index = index;
    promptElement.dataset.key = interaction.key;

    promptElement.innerHTML = `
        <div class="key-container">
            <div class="key-outline">
                <span class="key-text">${interaction.key}</span>
            </div>
        </div>
        <div class="action-container">
            <div class="action-text">${interaction.label}</div>
            ${interaction.description ? `<div class="action-description">${interaction.description}</div>` : ''}
        </div>
    `;

    return promptElement;
}

function hideInteraction() {
    const container = document.getElementById('viinteract-container');
    
    container.classList.add('sliding-out');
    
    setTimeout(() => {
        container.classList.remove('visible', 'sliding-out');
        isVisible = false;
        currentInteractions = [];
        
        sendToGame('interactionVisibilityChanged', { visible: false });
    }, 300);
}

function updateSelectedOption(index, key) {
    if (!isVisible) return;
    
    const options = document.querySelectorAll('.interact-option');
    
    options.forEach(option => option.classList.remove('active'));
    
    activeInteractionIndex = index;
    if (options[activeInteractionIndex]) {
        options[activeInteractionIndex].classList.add('active');
    }
}

function triggerKeyAnimation(key) {
    if (!isVisible) return;
    
    const keyElements = document.querySelectorAll('.key-outline');
    
    keyElements.forEach(keyElement => {
        if (keyElement.querySelector('.key-text').textContent === key) {
            keyElement.classList.add('key-press-animation');
            
            setTimeout(() => {
                keyElement.classList.remove('key-press-animation');
            }, 300);
        }
    });
}

function sendToGame(action, data = {}) {
    fetch(`https://${GetParentResourceName()}/${action}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(data)
    }).catch(error => console.error('Error sending data to game:', error));
}

window.InteractionSystem = {
    show: showInteraction,
    hide: hideInteraction,
    triggerKeyAnimation: triggerKeyAnimation
};