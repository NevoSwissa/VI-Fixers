let activeNotificationTimer = null;

window.addEventListener('message', function(event) {
    let data = event.data;
    
    if (data.type === "showVINotification") {
        displayVINotification(data);
    } else if (data.type === "hideVINotification") {
        hideVINotification();
    }
});

function displayVINotification(data) {
    if (activeNotificationTimer) {
        clearTimeout(activeNotificationTimer);
        hideVINotification();
    }
    
    const container = document.createElement('div');
    container.className = 'vinotification-container';
    
    let statusClass = 'success';
    if (data.status === 'danger') {
        statusClass = 'danger';
    } else if (data.status === 'warning') {
        statusClass = 'warning';
    }
    
    container.innerHTML = `
        <div class="vinotification-box ${statusClass}">
            <div class="vinotification-content">
                <div class="vinotification-icon"></div>
                <div class="vinotification-title">${data.title}</div>
                <div class="vinotification-signal">
                    <div class="vinotification-signal-bar"></div>
                    <div class="vinotification-signal-bar"></div>
                    <div class="vinotification-signal-bar"></div>
                </div>
            </div>
        </div>
    `;
    
    document.body.appendChild(container);
    
    if (data.flashScreen !== false) {
        const flash = document.createElement('div');
        flash.style.position = 'fixed';
        flash.style.top = '0';
        flash.style.left = '0';
        flash.style.width = '100%';
        flash.style.height = '100%';
        flash.style.backgroundColor = statusClass === 'danger' ? 'rgba(255, 45, 85, 0.1)' : 
                                     statusClass === 'warning' ? 'rgba(255, 188, 66, 0.1)' : 
                                     'rgba(5, 255, 161, 0.1)';
        flash.style.zIndex = '998';
        flash.style.pointerEvents = 'none';
        document.body.appendChild(flash);
        
        setTimeout(() => {
            flash.style.transition = 'opacity 0.5s ease';
            flash.style.opacity = '0';
            setTimeout(() => {
                document.body.removeChild(flash);
            }, 500);
        }, 300);
    }
    
    setTimeout(() => {
        container.classList.add('active');
        container.classList.add('slide-in');
                
        const displayTime = data.displayTime || 5000;
        activeNotificationTimer = setTimeout(() => {
            hideVINotification();
        }, displayTime);
    }, 10);
}

function hideVINotification() {
    const notifications = document.querySelectorAll('.vinotification-container');
    notifications.forEach(notification => {
        notification.classList.remove('active');
        notification.classList.add('slide-out');
        
        setTimeout(() => {
            if (notification.parentNode) {
                notification.parentNode.removeChild(notification);
            }
        }, 500);
    });
    
    activeNotificationTimer = null;
}