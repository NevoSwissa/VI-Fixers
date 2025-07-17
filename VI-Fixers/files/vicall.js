class ViCall {
    constructor() {
        this.container = document.getElementById('vicall-container');
        this.incomingContainer = document.getElementById('vicall-incoming');
        this.callerName = document.getElementById('vicall-caller-name');
        this.incomingCallerName = document.getElementById('vicall-incoming-caller');
        this.duration = document.getElementById('vicall-duration');
        this.timeoutDisplay = document.getElementById('vicall-timeout');
        this.isActive = false;
        this.isIncoming = false;
        this.startTime = null;
        this.durationInterval = null;
        this.timeoutInterval = null;
        this.timeoutSeconds = 5;
    }

    showIncoming(callerName = 'UNKNOWN CALLER', timeout = 5) {
        if (this.isActive || this.isIncoming) return;

        this.isIncoming = true;
        this.timeoutSeconds = timeout;
        this.incomingCallerName.textContent = callerName.toUpperCase();
        this.incomingCallerName.setAttribute('data-text', callerName.toUpperCase());

        this.container.classList.add('active', 'slide-in', 'incoming-mode');
        this.container.classList.remove('slide-out');
        this.incomingContainer.style.display = 'block';

        this.startTimeoutCountdown();
    }

    startTimeoutCountdown() {
        this.updateTimeoutDisplay();
        this.timeoutInterval = setInterval(() => {
            this.timeoutSeconds--;
            this.updateTimeoutDisplay();

            if (this.timeoutSeconds <= 0) {
                this.handleTimeout();
            }
        }, 1000);
    }

    updateTimeoutDisplay() {
        if (this.timeoutDisplay) {
            this.timeoutDisplay.textContent = `${this.timeoutSeconds}s`;
        }
    }

    handleTimeout() {
        if (this.timeoutInterval) {
            clearInterval(this.timeoutInterval);
            this.timeoutInterval = null;
        }
        this.hideIncoming();
    }

    hideIncoming() {
        if (!this.isIncoming) return;

        this.isIncoming = false;

        if (this.timeoutInterval) {
            clearInterval(this.timeoutInterval);
            this.timeoutInterval = null;
        }

        this.container.classList.add('slide-out');
        this.container.classList.remove('active', 'slide-in', 'incoming-mode');
        this.incomingContainer.style.display = 'none';

        this.incomingCallerName.removeAttribute('data-text');

        setTimeout(() => {
            this.container.classList.remove('slide-out');
        }, 600);
    }

    show(callerName = 'UNKNOWN CALLER') {
        if (this.isIncoming) {
            this.hideIncoming();
        }

        if (this.isActive) return;

        this.isActive = true;
        this.callerName.textContent = callerName.toUpperCase();
        this.startTime = Date.now();
        this.callerName.setAttribute('data-text', callerName.toUpperCase());

        this.incomingContainer.style.display = 'none';
        this.container.classList.add('active', 'slide-in');
        this.container.classList.remove('slide-out', 'incoming-mode');

        this.durationInterval = setInterval(() => {
            this.updateDuration();
        }, 1000);
    }

    hide() {
        if (this.isIncoming) {
            this.hideIncoming();
            return;
        }

        if (!this.isActive) return;

        this.isActive = false;
        this.container.classList.add('slide-out');
        this.container.classList.remove('active', 'slide-in', 'incoming-mode');

        if (this.durationInterval) {
            clearInterval(this.durationInterval);
            this.durationInterval = null;
        }

        this.duration.textContent = '00:00';
        this.callerName.removeAttribute('data-text');

        setTimeout(() => {
            this.container.classList.remove('slide-out');
        }, 600);
    }

    updateDuration() {
        if (!this.startTime) return;
        const elapsed = Math.floor((Date.now() - this.startTime) / 1000);
        const minutes = Math.floor(elapsed / 60);
        const seconds = elapsed % 60;
        this.duration.textContent =
            `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
    }

    handleMessage(data) {
        switch (data.type) {
            case 'vicall-show-incoming':
                this.showIncoming(data.caller, data.timeout);
                break;
            case 'vicall-show':
                this.show(data.caller);
                break;
            case 'vicall-hide':
                this.hide();
                break;
            case 'vicall-audio-ended':
                setTimeout(() => {
                    this.hide();
                }, 1000);
            break;
        }
    }
}

const viCall = new ViCall();
window.addEventListener('message', (event) => {
    viCall.handleMessage(event.data);
});