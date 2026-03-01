(function () {
    var panel = null;
    var countEl = null;
    var listEl = null;
    var initialized = false;

    function getBaseUrl() {
        return '/Notifications';
    }

    function getAntiForgeryToken() {
        var tokenEl = document.querySelector('input[name="__RequestVerificationToken"]');
        return tokenEl ? tokenEl.value : '';
    }

    function updateBadge(count) {
        if (!countEl) {
            return;
        }

        var safeCount = Number.isFinite(count) ? count : 0;
        countEl.textContent = safeCount.toString();
        countEl.style.display = safeCount > 0 ? 'flex' : 'none';
    }

    function escapeHtml(value) {
        if (!value) {
            return '';
        }

        return value
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#039;');
    }

    function formatTime(value) {
        if (!value) {
            return '';
        }

        var when = new Date(value);
        if (Number.isNaN(when.getTime())) {
            return value;
        }

        var diffMs = Date.now() - when.getTime();
        if (diffMs < 0) {
            return when.toLocaleString('vi-VN');
        }

        var minuteMs = 60000;
        var hourMs = 60 * minuteMs;
        var dayMs = 24 * hourMs;

        if (diffMs < minuteMs) {
            return 'just now';
        }

        if (diffMs < hourMs) {
            return Math.floor(diffMs / minuteMs) + 'm ago';
        }

        if (diffMs < dayMs) {
            return Math.floor(diffMs / hourMs) + 'h ago';
        }

        return when.getFullYear() + '-'
            + String(when.getMonth() + 1).padStart(2, '0') + '-'
            + String(when.getDate()).padStart(2, '0') + ' '
            + String(when.getHours()).padStart(2, '0') + ':'
            + String(when.getMinutes()).padStart(2, '0');
    }

    function buildItem(notification) {
        var item = document.createElement('div');
        item.className = 'notification-item' + (notification.isRead ? '' : ' unread');
        item.dataset.notificationId = notification.notificationId;
        item.dataset.deepLink = notification.deepLink || '';

        var title = escapeHtml(notification.title || 'Notification');
        var message = escapeHtml(notification.message || '');
        var timeText = formatTime(notification.createdAtUtc);

        item.innerHTML = ''
            + '<div class="notification-content">'
            + '  <div class="notification-title">' + title + '</div>'
            + '  <div class="notification-meta">' + message + '</div>'
            + '  <div class="notification-time">' + escapeHtml(timeText) + '</div>'
            + '</div>';

        item.addEventListener('click', function () {
            handleItemClick(item);
        });

        return item;
    }

    function renderNotifications(items) {
        if (!listEl) {
            return;
        }

        listEl.innerHTML = '';
        if (!items || items.length === 0) {
            listEl.innerHTML = '<div class="empty-notifications"><i class="fas fa-bell-slash"></i><p>No new notifications</p></div>';
            return;
        }

        items.forEach(function (item) {
            listEl.appendChild(buildItem(item));
        });
    }

    async function loadNotifications() {
        var response = await fetch(getBaseUrl() + '?handler=Notifications&page=1&pageSize=20');
        if (!response.ok) {
            return;
        }

        var payload = await response.json();
        renderNotifications(payload.items || []);
    }

    async function loadUnreadCount() {
        var response = await fetch(getBaseUrl() + '?handler=UnreadCount');
        if (!response.ok) {
            return;
        }

        var payload = await response.json();
        var count = payload.count ?? payload.Count ?? 0;
        updateBadge(Number(count));
    }

    async function markAsRead(notificationId) {
        var token = getAntiForgeryToken();
        var body = new URLSearchParams();
        body.append('notificationId', String(notificationId));

        await fetch(getBaseUrl() + '?handler=MarkRead', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
                'RequestVerificationToken': token
            },
            body: body.toString()
        });
    }

    async function markAllAsRead() {
        var token = getAntiForgeryToken();

        await fetch(getBaseUrl() + '?handler=MarkAllRead', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
                'RequestVerificationToken': token
            }
        });
    }

    async function handleItemClick(item) {
        var notificationId = item.dataset.notificationId;
        var deepLink = item.dataset.deepLink;
        var isUnread = item.classList.contains('unread');

        if (isUnread && notificationId) {
            await markAsRead(notificationId);
            item.classList.remove('unread');
            var currentCount = parseInt(countEl && countEl.textContent ? countEl.textContent : '0', 10);
            updateBadge(Math.max(0, currentCount - 1));
        }

        if (deepLink) {
            window.location.href = deepLink;
        }
    }

    function prependNotification(notification) {
        if (!listEl) {
            return;
        }

        var emptyState = listEl.querySelector('.empty-notifications');
        if (emptyState) {
            emptyState.remove();
        }

        listEl.prepend(buildItem(notification));
        var currentCount = parseInt(countEl && countEl.textContent ? countEl.textContent : '0', 10);
        updateBadge((Number.isNaN(currentCount) ? 0 : currentCount) + 1);
    }

    async function connectNotificationHub() {
        if (!window.signalR) {
            return;
        }

        var connection = new signalR.HubConnectionBuilder()
            .withUrl('/notificationHub')
            .withAutomaticReconnect()
            .build();

        connection.on('ReceiveNotification', function (notification) {
            prependNotification(notification);
        });

        try {
            await connection.start();
        } catch (e) {
            console.error('Notification hub connection failed:', e);
        }
    }

    async function initializeNotifications() {
        panel = document.getElementById('notificationPanel');
        countEl = document.getElementById('notificationCount');
        listEl = document.getElementById('notificationList');

        if (!panel || !countEl || !listEl || initialized) {
            return;
        }

        initialized = true;
        await loadNotifications();
        await loadUnreadCount();
        await connectNotificationHub();

        document.addEventListener('click', function (event) {
            var bell = document.getElementById('notificationBell');
            if (!bell || bell.contains(event.target)) {
                return;
            }

            panel.classList.remove('open');
        });
    }

    window.toggleNotificationPanel = function () {
        if (!panel) {
            panel = document.getElementById('notificationPanel');
        }

        if (!panel) {
            return;
        }

        panel.classList.toggle('open');
    };

    window.clearAllNotifications = async function () {
        await markAllAsRead();
        updateBadge(0);
        renderNotifications([]);
    };

    document.addEventListener('DOMContentLoaded', function () {
        initializeNotifications();
    });
})();
