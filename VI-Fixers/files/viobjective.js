(() => {
    let currentObjectiveId = null;
    let objectiveTimeout = null;
    let objectiveInterval = null;
    let objectiveData = {};
    let progressBarValue = 0;
    let isInitialized = false;

    window.addEventListener('message', (event) => {
        const data = event.data;

        if (!data || !data.type) return;

        switch (data.type) {
            case 'showVIObjective':
                showObjective(data);
            break;
            case 'updateVIObjective':
                updateObjective(data);
            break;
            case 'hideVIObjective':
                hideObjective(data);
            break;
            case 'updateVIObjectiveProgress':
                updateObjectiveProgress(data);
            break;
        }
    });

    const initialize = () => {
        if (isInitialized) return;

        const objectiveContainer = document.createElement('div');
        objectiveContainer.id = 'viobjective-container';
        document.body.appendChild(objectiveContainer);

        objectiveContainer.innerHTML = `
            <div class="objective-mission">
                <div class="objective-icon">
                    <i class="fas fa-crosshairs"></i>
                </div>
                <div class="objective-title" id="objective-title"></div>
            </div>
            <div class="objective-divider"></div>
            <div class="objective-text" id="objective-text"></div>
            <div class="objective-progress" id="objective-progress-container">
                <div class="objective-progress-bar" id="objective-progress-bar"></div>
            </div>
            <div class="objective-optional" id="objective-optional"></div>
        `;

        isInitialized = true;
    };

    const showObjective = (data) => {
        if (!isInitialized) initialize();

        if (objectiveTimeout) {
            clearTimeout(objectiveTimeout);
            objectiveTimeout = null;
        }
        
        if (objectiveInterval) {
            clearInterval(objectiveInterval);
            objectiveInterval = null;
        }

        objectiveData = {
            id: data.id || `objective_${Date.now()}`,
            title: data.title || 'MISSION',
            text: data.text || 'No objective text provided',
            displayTime: data.displayTime || 0,
            progress: data.progress || 0,
            showProgress: data.showProgress || false,
            optionalText: data.optionalText || null
        };
        
        currentObjectiveId = objectiveData.id;

        const container = document.getElementById('viobjective-container');
        const titleElement = document.getElementById('objective-title');
        const textElement = document.getElementById('objective-text');
        const progressContainer = document.getElementById('objective-progress-container');
        const progressBar = document.getElementById('objective-progress-bar');
        const optionalElement = document.getElementById('objective-optional');

        titleElement.textContent = objectiveData.title;
        textElement.textContent = objectiveData.text;
        
        if (objectiveData.showProgress) {
            progressBarValue = objectiveData.progress;
            progressBar.style.width = `${progressBarValue}%`;
            progressContainer.style.display = 'block';
        } else {
            progressContainer.style.display = 'none';
        }
        
        if (objectiveData.optionalText) {
            optionalElement.textContent = `OPTIONAL: ${objectiveData.optionalText}`;
            optionalElement.style.display = 'block';
        } else {
            optionalElement.style.display = 'none';
        }

        container.classList.remove('fade-out');
        container.classList.add('visible', 'objective-flash');
        
        setTimeout(() => {
            container.classList.remove('objective-flash');
        }, 1000);
        
        if (objectiveData.displayTime > 0) {
            objectiveTimeout = setTimeout(() => {
                hideObjective();
            }, objectiveData.displayTime);
        }
    };

    const updateObjective = (data) => {
        if (!isInitialized) {
            showObjective(data);
            return;
        }

        if (data.title) objectiveData.title = data.title;
        if (data.text) objectiveData.text = data.text;
        if (data.showProgress !== undefined) objectiveData.showProgress = data.showProgress;
        if (data.progress !== undefined) objectiveData.progress = data.progress;
        if (data.optionalText !== undefined) objectiveData.optionalText = data.optionalText;
        
        const container = document.getElementById('viobjective-container');
        const titleElement = document.getElementById('objective-title');
        const textElement = document.getElementById('objective-text');
        const progressContainer = document.getElementById('objective-progress-container');
        const progressBar = document.getElementById('objective-progress-bar');
        const optionalElement = document.getElementById('objective-optional');

        container.classList.add('updating');
        
        titleElement.textContent = objectiveData.title;
        textElement.textContent = objectiveData.text;
        
        if (objectiveData.showProgress) {
            progressBarValue = objectiveData.progress;
            progressBar.style.width = `${progressBarValue}%`;
            progressContainer.style.display = 'block';
        } else {
            progressContainer.style.display = 'none';
        }
        
        if (objectiveData.optionalText) {
            optionalElement.textContent = `OPTIONAL: ${objectiveData.optionalText}`;
            optionalElement.style.display = 'block';
        } else {
            optionalElement.style.display = 'none';
        }

        container.classList.remove('fade-out');
        container.classList.add('visible', 'objective-flash');
        
        setTimeout(() => {
            container.classList.remove('objective-flash', 'updating');
        }, 1000);
    };

    const updateObjectiveProgress = (data) => {
        if (!isInitialized || !objectiveData.showProgress) return;
        
        const newProgress = data.progress || 0;
        const progressBar = document.getElementById('objective-progress-bar');
        
        let startValue = progressBarValue;
        let endValue = newProgress;
        let duration = data.animationDuration || 500;
        let startTime = null;
        
        const animateProgress = (timestamp) => {
            if (!startTime) startTime = timestamp;
            const elapsed = timestamp - startTime;
            const progress = Math.min(elapsed / duration, 1);
            
            const currentValue = startValue + (endValue - startValue) * progress;
            progressBar.style.width = `${currentValue}%`;
            
            if (progress < 1) {
                requestAnimationFrame(animateProgress);
            } else {
                progressBarValue = endValue;
            }
        };
        
        requestAnimationFrame(animateProgress);
    };

    const hideObjective = (data) => {
        if (!isInitialized) return;
        
        const container = document.getElementById('viobjective-container');
        
        if (data && data.id && data.id !== currentObjectiveId) return;
        
        container.classList.add('fade-out');
        container.classList.remove('visible');
        
        if (objectiveTimeout) {
            clearTimeout(objectiveTimeout);
            objectiveTimeout = null;
        }
        
        if (objectiveInterval) {
            clearInterval(objectiveInterval);
            objectiveInterval = null;
        }
        
        currentObjectiveId = null;
    };

    initialize();
})();