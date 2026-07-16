// 1. Управление вкладками
function switchTab(tabId, buttonElement) {
    document.querySelectorAll('.tab-content').forEach(function(tab) {
        tab.classList.remove('active');
    });
    document.querySelectorAll('.tab-btn').forEach(function(btn) {
        btn.classList.remove('active');
    });
    
    document.getElementById(tabId).classList.add('active');
    buttonElement.classList.add('active');
}

// 2. Отображение активных подключений
function refreshMounts() {
    const listContainer = document.getElementById('mount-list-card');
    if (!listContainer || !window.cockpit) return;

    cockpit.spawn(["findmnt", "-t", "cifs", "--json"])
        .done(function(output) {
            try {
                const data = JSON.parse(output);
                
                while (listContainer.firstChild) {
                    listContainer.removeChild(listContainer.firstChild);
                }

                const title = document.createElement('h3');
                title.textContent = 'Активные подключения';
                listContainer.appendChild(title);

                const divList = document.createElement('div');
                divList.style.marginTop = '15px';
                
                data.filesystems.forEach(function(fs) {
                    const itemContainer = document.createElement('div');
                    itemContainer.classList.add('mount-item-container');

                    const itemInfo = document.createElement('div');
                    itemInfo.classList.add('mount-item-info');

                    const b = document.createElement('b');
                    b.style.color = 'var(--cockpit-color-text-link)';
                    b.textContent = fs.target;
                    
                    const br = document.createElement('br');
                    
                    const small = document.createElement('small');
                    small.classList.add('text-muted');
                    small.textContent = 'Источник: ' + fs.source;

                    itemInfo.appendChild(b);
                    itemInfo.appendChild(br);
                    itemInfo.appendChild(small);

                    const btnUmount = document.createElement('button');
                    btnUmount.classList.add('btn-umount');
                    btnUmount.textContent = 'Отключить';
                    
                    btnUmount.addEventListener('click', function() {
                        btnUmount.disabled = true;
                        btnUmount.textContent = 'Выталкиваю...';

                        cockpit.spawn(["/usr/share/cockpit/samba-easycontrol/umount-helper.sh", fs.target])
                            .done(function() {
                                refreshMounts();
                            })
                            .fail(function(error, stderr) {
                                let errorText = stderr ? stderr : (error.message ? error.message : error);
                                alert("Ошибка размонтирования:\n" + errorText);
                                btnUmount.disabled = false;
                                btnUmount.textContent = 'Отключить';
                            });
                    });

                    itemContainer.appendChild(itemInfo);
                    itemContainer.appendChild(btnUmount);
                    divList.appendChild(itemContainer);
                });
                
                listContainer.appendChild(divList);
            } catch (e) {
                // Стабильность при парсинге
            }
        })
        .fail(function() {
            while (listContainer.firstChild) {
                listContainer.removeChild(listContainer.firstChild);
            }
            const title = document.createElement('h3');
            title.textContent = 'Активные подключения';
            const p = document.createElement('p');
            p.classList.add('text-muted');
            p.style.marginTop = '15px';
            p.textContent = 'Нет активных сетевых подключений.';
            listContainer.appendChild(title);
            listContainer.appendChild(p);
        });
}

// Функция для опроса системы и вывода списка папок общего доступа (серверных шар)
// 3. Отображение списка папок общего доступа (серверных шар)
function refreshShares() {
    const listContainer = document.getElementById('share-tab');
    if (!listContainer || !window.cockpit) return;
    
    // Находим именно правую карточку внутри вкладки раздачи
    const rightCard = listContainer.querySelector('.grid .card:last-child');
    if (!rightCard) return;

    cockpit.spawn(["/usr/share/cockpit/samba-easycontrol/share-list.sh"])
        .done(function(output) {
            // Безопасно очищаем контейнер правой карточки
            while (rightCard.firstChild) {
                rightCard.removeChild(rightCard.firstChild);
            }

            const title = document.createElement('h3');
            title.textContent = 'Общие папки (Пассивные шары)';
            rightCard.appendChild(title);

            const trimmedOutput = output.trim();
            if (!trimmedOutput) {
                const p = document.createElement('p');
                p.classList.add('text-muted');
                p.style.marginTop = '15px';
                p.textContent = 'Сервер пока ничего не раздает в сеть.';
                rightCard.appendChild(p);
                return;
            }

            const divList = document.createElement('div');
            divList.style.marginTop = '15px';

            const lines = trimmedOutput.split('\n');
            lines.forEach(function(line) {
                if (!line) return;

                const parts = line.split(';');
                if (parts.length === 3) {
                    const rawName = parts[0];
                    // Очищаем имя от квадратных скобок для корректной передачи в bash-скрипт удаления
                    const shareName = rawName.replace(/[\[\]]/g, '').trim();
                    const localPath = parts[1];
                    const accessType = parts[2];

                    const itemContainer = document.createElement('div');
                    itemContainer.classList.add('mount-item-container');

                    const itemInfo = document.createElement('div');
                    itemInfo.classList.add('mount-item-info');

                    const b = document.createElement('b');
                    b.style.color = 'var(--cockpit-color-text-link)';
                    b.textContent = '[' + shareName + ']';

                    const br = document.createElement('br');

                    const smallPath = document.createElement('small');
                    smallPath.classList.add('text-muted');
                    smallPath.textContent = 'Путь: ' + localPath + ' ';

                    const badgeAccess = document.createElement('span');
                    badgeAccess.style.fontSize = '11px';
                    badgeAccess.style.padding = '2px 6px';
                    badgeAccess.style.borderRadius = '3px';
                    badgeAccess.style.fontWeight = 'bold';
                    badgeAccess.style.marginLeft = '5px';

                    if (accessType === 'guest') {
                        badgeAccess.textContent = 'Гость';
                        badgeAccess.style.background = 'var(--cockpit-color-bg-canvas, #f0f2f5)';
                        badgeAccess.style.color = 'var(--cockpit-color-text, #151515)';
                    } else {
                        badgeAccess.textContent = 'Приватная';
                        badgeAccess.style.background = 'var(--cockpit-color-text-link, #0066cc)';
                        badgeAccess.style.color = '#fff';
                    }

                    itemInfo.appendChild(b);
                    itemInfo.appendChild(br);
                    itemInfo.appendChild(smallPath);
                    itemInfo.appendChild(badgeAccess);

                    // Кнопка закрытия сетевого доступа
                    const btnRemoveShare = document.createElement('button');
                    btnRemoveShare.classList.add('btn-umount');
                    btnRemoveShare.textContent = 'Закрыть доступ';
                    
                    btnRemoveShare.addEventListener('click', function() {
                        btnRemoveShare.disabled = true;
                        btnRemoveShare.textContent = 'Закрываю...';

                        cockpit.spawn(["/usr/share/cockpit/samba-easycontrol/share-remove.sh", shareName])
                            .done(function() {
                                refreshShares();
                            })
                            .fail(function(error, stderr) {
                                let errorText = stderr ? stderr : (error.message ? error.message : error);
                                alert("Ошибка закрытия доступа:\n" + errorText);
                                btnRemoveShare.disabled = false;
                                btnRemoveShare.textContent = 'Закрыть доступ';
                            });
                    });

                    itemContainer.appendChild(itemInfo);
                    itemContainer.appendChild(btnRemoveShare);
                    divList.appendChild(itemContainer);
                }
            });

            rightCard.appendChild(divList);
        })
        .fail(function() {
            while (rightCard.firstChild) {
                rightCard.removeChild(rightCard.firstChild);
            }
            const title = document.createElement('h3');
            title.textContent = 'Общие папки (Пассивные шары)';
            const p = document.createElement('p');
            p.classList.add('text-muted');
            p.style.marginTop = '15px';
            p.textContent = 'Ошибка при получении списка общих папок.';
            rightCard.appendChild(title);
            rightCard.appendChild(p);
        });
}


// 3. Высокоскоростной сканер сети
function scanNetwork() {
    const btnScan = document.getElementById('btn-scan');
    const resultsBlock = document.getElementById('scan-results');
    const hostsList = document.getElementById('scan-hosts-list');

    if (!window.cockpit || !btnScan) return;

    btnScan.disabled = true;
    btnScan.innerText = "Сканирую...";
    
    while (hostsList.firstChild) {
        hostsList.removeChild(hostsList.firstChild);
    }
    const loadingText = document.createElement('span');
    loadingText.classList.add('text-muted');
    loadingText.textContent = 'Поиск устройств в подсети...';
    hostsList.appendChild(loadingText);
    
    resultsBlock.style.display = 'block';

    cockpit.spawn(["/usr/share/cockpit/samba-easycontrol/scan-helper.sh"])
        .done(function(output) {
            while (hostsList.firstChild) {
                hostsList.removeChild(hostsList.firstChild);
            }
            
            if (!output.trim()) {
                const noDevices = document.createElement('span');
                noDevices.classList.add('text-muted');
                noDevices.textContent = 'Samba/Windows серверы в сети не найдены.';
                hostsList.appendChild(noDevices);
                return;
            }

            const lines = output.trim().split('\n');
            let foundCount = 0;

            lines.forEach(function(line) {
                if (!line) return;
                
                const parts = line.split(';');
                if (parts.length === 2) {
                    const ip = parts[0];
                    const name = parts[1];
                    foundCount++;

                    const badge = document.createElement('span');
                    badge.style.cssText = "background: var(--cockpit-color-bg-canvas, #f0f2f5); border: 1px solid var(--cockpit-color-border, #d2d2d2); padding: 6px 12px; border-radius: 4px; cursor: pointer; font-size: 13px; font-weight: 600; color: var(--cockpit-color-text, #151515); display: inline-block; transition: background 0.2s;";
                    badge.textContent = `🖥️ ${name} (${ip})`;
                    
                    badge.addEventListener('mouseenter', function() { badge.style.background = 'var(--cockpit-color-bg-surface)'; });
                    badge.addEventListener('mouseleave', function() { badge.style.background = 'var(--cockpit-color-bg-canvas)'; });

                    badge.addEventListener('click', function() {
                        document.getElementById('mount-smb-path').value = `//${ip}/`;
                        document.getElementById('mount-smb-path').focus();
                        // Запускаем опрос папок для этого IP
                        fetchDeviceShares(ip);
                    });

                    hostsList.appendChild(badge);
                }
            });

            if (foundCount === 0) {
                const noDevices = document.createElement('span');
                noDevices.classList.add('text-muted');
                noDevices.textContent = 'Samba/Windows серверы в сети не найдены.';
                hostsList.appendChild(noDevices);
            }
        })
        .fail(function(error) {
            while (hostsList.firstChild) {
                hostsList.removeChild(hostsList.firstChild);
            }
            const errorSpan = document.createElement('span');
            errorSpan.classList.add('text-danger');
            errorSpan.textContent = 'Ошибка сканирования подсети: ' + error.message;
            hostsList.appendChild(errorSpan);
        })
        .always(function() {
            btnScan.disabled = false;
            btnScan.innerText = "Найти в сети";
        });
}

// Функция опроса доступных шар на конкретном удаленном IP (ИСПРАВЛЕНО ДЛЯ ЧИСТЫХ СИСТЕМ)
function fetchDeviceShares(ip) {
    const shareResultsBlock = document.getElementById('share-results');
    const sharesList = document.getElementById('scan-shares-list');

    if (!window.cockpit || !shareResultsBlock || !sharesList) return;

    shareResultsBlock.style.display = 'block';
    while (sharesList.firstChild) {
        sharesList.removeChild(sharesList.firstChild);
    }

    const loading = document.createElement('span');
    loading.classList.add('text-muted');
    loading.textContent = 'Опрашиваю устройство...';
    sharesList.appendChild(loading);

    // ИСПРАВЛЕНО: Добавлен аргумент "-U", "%" для исключения интерактивных запросов пароля в Debian
    cockpit.spawn(["smbclient", "-L", "//" + ip, "-N", "-U", "%", "-g"])
        .done(function(output) {
            while (sharesList.firstChild) {
                sharesList.removeChild(sharesList.firstChild);
            }

            const lines = output.trim().split('\n');
            let foundSharesCount = 0;

            lines.forEach(function(line) {
                const parts = line.split('|');
                if (parts[0] === 'Disk') {
                    const shareName = parts[1].trim();

                    if (shareName.indexOf('$') === -1) {
                        foundSharesCount++;

                        const shareBadge = document.createElement('span');
                        shareBadge.classList.add('badge-share-item');
                        shareBadge.textContent = `📁 ${shareName}`;

                        shareBadge.addEventListener('mouseenter', function() { shareBadge.style.background = 'var(--cockpit-color-bg-canvas)'; });
                        shareBadge.addEventListener('mouseleave', function() { shareBadge.style.background = 'var(--cockpit-color-bg-surface)'; });

                        // ИСПРАВЛЕННЫЙ БЛОК ДЛЯ ВАШЕГО СТАРОГО INDEX.JS
                        shareBadge.addEventListener('click', function() {
                        document.getElementById('mount-smb-path').value = '//' + ip + '/' + shareName;
    
                        // Прямое и надежное получение имени пользователя текущей сессии Cockpit
                        let username = (window.cockpit && window.cockpit.user) ? cockpit.user.name : "";
    
                            if (username && username !== "root") {
                            document.getElementById('mount-local-path').value = '/home/' + username + '/' + shareName;
                            } else {
                            document.getElementById('mount-local-path').value = '/mnt/' + shareName;
                            }
                            // КРИТИЧЕСКИ ВАЖНО: Запускаем проверку сразу после того, как JS подставил путь автоматикой
                            checkMountCollision();
                        });


                        sharesList.appendChild(shareBadge);
                    }
                }
            });

            if (foundSharesCount === 0) {
                const noShares = document.createElement('span');
                noShares.classList.add('text-muted');
                noShares.textContent = 'Доступные без пароля общие папки не найдены.';
                sharesList.appendChild(noShares);
            }
        })
        .fail(function() {
            while (sharesList.firstChild) {
                sharesList.removeChild(sharesList.firstChild);
            }
            const errorSpan = document.createElement('span');
            errorSpan.classList.add('text-muted');
            errorSpan.textContent = 'Не удалось получить список папок (требуется пароль).';
            sharesList.appendChild(errorSpan);
        });
}


// Функция проверки коллизии путей (ИСПРАВЛЕННАЯ СИНТАКСИЧЕСКАЯ ОШИБКА)
function checkMountCollision() {
    const localPathInput = document.getElementById('mount-local-path');
    const warningBlock = document.getElementById('mount-path-warning');
    const listCard = document.getElementById('mount-list-card');
    
    if (!localPathInput || !warningBlock) return;
    
    const currentPath = localPathInput.value.trim();
    
    // Если поле пустое — гарантированно скрываем надпись и выходим
    if (currentPath === "") {
        warningBlock.style.display = "none";
        return;
    }

    // Собираем пути из списка активных подключений
    const activeTargets = [];
    if (listCard) {
        const boldElements = listCard.querySelectorAll('b');
        boldElements.forEach(function(b) {
            const pathText = b.textContent.trim();
            if (pathText && pathText !== "Активные подключения") {
                activeTargets.push(pathText);
            }
        });
    }

    // Проверяем, есть ли введённый путь в списке уже смонтированных
    if (activeTargets.indexOf(currentPath) !== -1) {
        warningBlock.style.display = "block";
    } else {
        warningBlock.style.display = "none";
    }
}




// 4. Инициализация при загрузке DOM
document.addEventListener('DOMContentLoaded', function() {
    // Вкладки
    document.getElementById('btn-mount').addEventListener('click', function() { switchTab('mount-tab', this); });
    document.getElementById('btn-share').addEventListener('click', function() { switchTab('share-tab', this); });
    document.getElementById('btn-about').addEventListener('click', function() { switchTab('about-tab', this); });

    // ДОБАВЛЕНО: Отслеживаем ручной ввод пользователя в поле точки монтирования
    const localPathInput = document.getElementById('mount-local-path');
    if (localPathInput) {
        localPathInput.addEventListener('input', checkMountCollision);
    }
    // Запускаем проверку один раз при старте, чтобы гарантированно скрыть блок
    checkMountCollision();

    // Кнопка сканирования
    const btnScan = document.getElementById('btn-scan');
    if (btnScan) {
        btnScan.addEventListener('click', scanNetwork);
    }

    // Рендер монтирований
    refreshMounts();
    refreshShares(); // ДОБАВЛЕНО: опрос шар при загрузке
    
    setInterval(refreshMounts, 5000);
    setInterval(refreshShares, 5000); // ДОБАВЛЕНО: автообновление шар каждые 5 сек

    // Обработчик формы монтирования
    document.getElementById('mount-form').addEventListener('submit', function(e) {
        e.preventDefault();
        if (!window.cockpit) return;

        const btnSubmit = e.target.querySelector('button[type="submit"]');
        const sharePath = document.getElementById('mount-smb-path').value.trim();
        const localPath = document.getElementById('mount-local-path').value.trim();
        const smbUser = document.getElementById('mount-user').value.trim();
        const smbPass = document.getElementById('mount-pass').value;

        // ЖЕЛЕЗОБЕТОННЫЙ МЕТОД: Берем UID/GID напрямую из системных переменных Cockpit
        // В обход cockpit.user, который может отдавать undefined в некоторых версиях ОС
        const currentUid = window.parent.cockpit.transport.options.user_id || "1000";
        const currentGid = window.parent.cockpit.transport.options.group_id || "1000";

        btnSubmit.disabled = true;
        btnSubmit.innerText = "Подключение...";

        cockpit.spawn([
            "/usr/share/cockpit/samba-easycontrol/mount-helper.sh",
            sharePath,
            localPath,
            smbUser,
            smbPass,
            String(currentUid),
            String(currentGid)
        ])
        .done(function() {
            document.getElementById('mount-smb-path').value = '';
            document.getElementById('mount-local-path').value = '';
            document.getElementById('mount-user').value = '';
            document.getElementById('mount-pass').value = '';
            // Мгновенно перерисовываем список активных подключений в правой панели
            refreshMounts();
        })
        .fail(function(error, stderr) {
            let errorText = stderr ? stderr : (error.message ? error.message : error);
            alert("Ошибка монтирования:\n" + errorText);
        })
        .always(function() {
            // Возвращаем кнопку в активное состояние
            btnSubmit.disabled = false;
            btnSubmit.innerText = "Подключить диск";
        });
    });

        // Обработчик формы создания сетевой шары (сервер)
    document.getElementById('share-form').addEventListener('submit', function(e) {
        e.preventDefault();
        if (!window.cockpit) return;

        const btnSubmit = e.target.querySelector('button[type="submit"]');
        
        // Собираем данные из полей ввода
        const shareName = document.getElementById('share-name').value.trim();
        const sharePath = document.getElementById('share-path').value.trim();
        const shareAccess = document.getElementById('share-access').value;

        // Блокируем кнопку на время работы скрипта
        btnSubmit.disabled = true;
        btnSubmit.innerText = "Открытие доступа...";

        // Вызываем наш bash-скрипт создания шары
        cockpit.spawn([
            "/usr/share/cockpit/samba-easycontrol/share-add.sh",
            shareName,
            sharePath,
            shareAccess
        ])
        .done(function() {
            // При успешном создании очищаем поля формы
            document.getElementById('share-name').value = '';
            document.getElementById('share-path').value = '';
            // Сбрасываем селект на гостевой доступ по умолчанию
            document.getElementById('share-access').value = 'guest';
            
            // Мгновенно обновляем список шар в правой панели
            refreshShares();
        })
        .fail(function(error, stderr) {
            // Если скрипт вернул exit 1 (например, имя шары уже занято), выводим ошибку
            let errorText = stderr ? stderr : (error.message ? error.message : error);
            alert("Ошибка создания шары:\n" + errorText);
        })
        .always(function() {
            // Возвращаем кнопку в исходное состояние
            btnSubmit.disabled = false;
            btnSubmit.innerText = "Открыть общий доступ";
        });
    });

});
