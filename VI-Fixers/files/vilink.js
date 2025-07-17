const viLinkContainer = document.getElementById('vilink-container');
const viLinkSender = document.getElementById('vilink-sender');
const viLinkSubject = document.getElementById('vilink-subject');
const viLinkMessage = document.getElementById('vilink-message');
const viLinkTimestamp = document.getElementById('vilink-timestamp');
const viLinkClose = document.getElementById('vilink-close');

const activeMessages = new Map();
let autoCloseTimeout = null;

function showVILink(id, data) {
    if (autoCloseTimeout) {
        clearTimeout(autoCloseTimeout);
    }

    viLinkSender.textContent = data.sender || 'UNKNOWN';
    viLinkSubject.textContent = data.subject || 'NO SUBJECT';

    let rawMessage = data.message;
    if (Array.isArray(rawMessage)) {
        rawMessage = rawMessage.join('\n');
    }

    const formattedMessage = (rawMessage || '').replace(/\n/g, '<br>');
    viLinkMessage.innerHTML = formattedMessage;

    const now = new Date();
    const hours = now.getHours().toString().padStart(2, '0');
    const minutes = now.getMinutes().toString().padStart(2, '0');
    viLinkTimestamp.textContent = `${hours}:${minutes}`;

    activeMessages.set(id, {
        ...data,
        timestamp: now
    });

    viLinkContainer.classList.remove('hidden');
    viLinkContainer.classList.add('slide-in');

    autoCloseTimeout = setTimeout(() => {
        hideVILink();
    }, data.displayTime || 8000);

    return id;
}

function hideVILink() {
    viLinkContainer.classList.remove('slide-in');
    viLinkContainer.classList.add('slide-out');
    
    setTimeout(() => {
        viLinkContainer.classList.add('hidden');
        viLinkContainer.classList.remove('slide-out');
    }, 500);
    
    if (autoCloseTimeout) {
        clearTimeout(autoCloseTimeout);
        autoCloseTimeout = null;
    }
}

window.addEventListener('message', function(event) {
    const data = event.data;
    
    if (data.type === 'showVILink') {
        const id = data.id || `msg_${Date.now()}`;
        showVILink(id, {
            sender: data.sender,
            subject: data.subject,
            message: data.message,
            displayTime: data.displayTime || 8000
        });
    } else if (data.type === 'hideVILink') {
        hideVILink();
    }
});