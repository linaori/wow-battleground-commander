local AddonName, Namespace = ...
local L = Namespace.Libs.AceLocale:NewLocale(AddonName, 'ruRU')
if not L then return end

L['Group Info'] = 'Информация о группе'
L['Ready Check'] = 'Проверка готовности'
L['Group Information'] = 'Информация о группе'
L['yes'] = 'да'
L['no'] = 'нет'
L['Merc'] = 'Наемник'
L['Deserter'] = 'Дезертир'
L['Ready'] = 'Готов'
L['Not Ready'] = 'Не готов'
L['Addon Information'] = 'Информация об аддоне'
L['Version'] = 'Версия'
L['Addon version: %s'] = 'Версия аддона: %s'
L['Battleground Tools'] = 'Настройки поля боя'
L['Instructions Frame'] = 'Поле инструкций'
L['Enable'] = 'Включить'
L['Enables or disables the instructions frame that captures raid warnings'] = 'Включает или отключает окно инструкций, куда записываются предупреждения рейда'
L['Font'] = 'Шрифт'
L['Font used for the text inside the frame'] = 'Шрифт для текста внутри поля инструкций'
L['Highlight Color'] = 'Цвет последнего сообщения'
L['Color of the most recent text message'] = 'Цвет самого последнего сообщения в поле инструций'
L['Text Color'] = 'Цвет остальных сообщений'
L['Color of the remaining text messages'] = 'Цвет остальных сообщений в поле инструкций'
L['Time Color'] = 'Цвет времени'
L['Color of the time text'] = 'Изменить цвет текста времени'
L['Font Flags'] = 'Параметры шрифта'
L['Adjust the font flags'] = 'Изменить параметры шрифта'
L['Allow Repositioning'] = 'Позволить перемещение'
L['Enable to reposition or resize the frame'] = 'Позволяет перемещать или менять размер окна инструкций'
L['Font Size'] = 'Размер шрифта'
L['Adjust the font size for the messages and time'] = 'Изменить размер шрифта сообщений и времени'
L['Enabled in Zones'] = 'Включено в локациях'
L['Select Zones'] = 'Выберите локации'
L['Select the zones where the frame should appear when enabled'] = 'Выберите локации, в которых будет показываться окно инструкций'
L['Frame Text Configuration'] = 'Конфигурация текста поля инструкций'
L['Maximum instructions'] = 'Максимум инструкций'
L['The maximum amount of instructions to show'] = 'Максимум показываемых инструкций'
L['Frame Layout'] = 'Настройки окна'
L['Background Texture'] = 'Текстура фона'
L['Changes the background texture of the frame'] = 'Изменить текстуру окна инструкций'
L['Border Texture'] = 'Окантовка'
L['Changes the border texture of the frame'] = 'Изменить окантовку окна инструкций'
L['Border Size'] = 'Ширина окантовки'
L['Changes the border size'] = 'Изменить ширину окантовки '
L['Background Inset'] = 'Размер фона'
L['Reduces the size of the background texture'] = 'Изменить размер текстуры фона'
L['Background Color'] = 'Цвет фона'
L['Border Color'] = 'Цвет окантовки'
L['Battleground Commander loaded'] = 'Battleground Commander загружен'
L['You can access the configuration via /bgc or through the interface options'] = 'Вы можете настроить аддон, используя команду /bgc или через опции интерфейса'
L['Latest message on top '] = 'Последнее сообщение сверху'
L['Enable to show the latest message on top, otherwise the latest message will be on the bottom'] = 'Показывать последнее сообщение сверху, в противном случае оно будет показано внизу'
L['Queue paused for %s'] = 'Очередь на %s остановлена'
L['Queue resumed for %s'] = 'Очередь на %s возобновлена'
L['As BG Leader'] = 'Как лидер БГ'
L['Requests lead upon entering or enabling this option'] = 'Запрашивать лидерство при заходе на поле боя'
L['Lead Requested'] = 'Лидерство запрошено'
L['%s is requesting lead'] = '%s запрашивает лидера'
L['%s people requested lead'] = '%s человек запрашивает лидерство'
L['Battleground Leader'] = 'Лидер поля боя'
L['Automatically Accept Request'] = 'Автоматически принимать запрос'
L['Automatically Reject Request'] = 'Автоматически отклонять запрос'
L['Players to automatically accept when they request lead'] = 'Автоматически давать лидера данным игрокам при запросе'
L['Players to automatically reject when they request lead'] = 'Автоматически отказывать в лидерстве данным игрокам при запросе'
L['Each player name goes on a new line. The format is "Playername" for players from your realm, and "Playername-Realname" for other realms.'] = 'Имя каждого игрока должно быть на новой строке. Формат "Имя_игрока" для вашего игрового мира, и "Имя_игрока-Мир" для других миров'
L['Automatically giving lead to %s'] = 'Автоматически отдаю лидера %s'
L['Enable Custom Message'] = 'Включить пользовательское сообщение'
L['Enable sending a custom message if the leader not using Battleground Commander'] = 'Отправлять пользовательско сообщение, если лидер не использует данный аддон'
L['Custom Message'] = 'Пользовательское сообщение'
L['{leader} will be replaced by the leader name in this message and is optional'] = '{leader} будет заменено на имя лидера в данном сообщении. Это опционально.'
L['Send Whisper (/w)'] = 'Шепот (/w)'
L['Send Say (/s)'] = 'Сказать (/s)'
L['Send Raid (/r)'] = 'Сообщение рейду (/r)'
L['Automation'] = 'Автоматизация'
L['Automatically Accept Role Selection'] = 'Автоматически принимать выбор роли'
L['Auto Accept Role'] = 'Автоматически принимать роль'
L['Accepts the pre-selected role when your group applies for a battleground'] = 'Принимать заранее выбранную роль, когда ваша группа встает в очередь на БГ'
L['Clear frame when exiting the battleground'] = 'Очищать окно по выходу с поля боя'
L['Removes the instructions from the last battleground'] = 'Очищает окно от инструкций с последнего поля боя'
L['Entered %s'] = 'Зашел на %s'
L['Ready Check on Queue Cancel'] = 'Проверка готовности при отмене очереди на БГ'
L['Do a ready check to see who entered while the group leader cancelled entering'] = 'Сделать проверку готовности для того, чтобы узнать кто зашел на БГ, на которое лидер сказал не заходить'
L['Open Battleground Commander Settings'] = 'Открыть опции аддона'
L['Accepted automated ready check with message: "%s"'] = 'Получен автоматический ответ при проверку готовности: "%s"'
L['Sending automated ready check with message: "%s"'] = 'Отправка автоматического ответа при проверке готовности: "%s"'
L['Cancel'] = 'Отмена'
L['Enter'] = 'Заходим'
L['Entry Management'] = 'Параметры вступления'
L['These features are only enabled when you are the group or raid leader'] = 'Эти опции доступны только если вы лидер группы или рейда'
L['Send "Enter" message in chat'] = 'Отправить сообщение "Enter" в чат'
L['Send "Cancel" message in chat'] = 'Отправить сообщение "Cancel" в чат'
L['Automatically send a message to the raid or party chat when you cancel the entry'] = 'Автоматически отправлять сообщение в группу или рейд если вы отменили вступление на БГ'
L['Automatically send a message to the raid or party chat when you confirm the entry'] = 'Автоматически отправлять сообщение в группу или рейд если вы вступили на БГ'
L['Queue Pause Detection'] = 'Мониторинг паузы очереди на БГ'
L['Auto Queue'] = 'Автоматическое вступление в очередь'
L['Declined'] = 'Отменено'
L['Entered'] = 'Вступил'
L['Status'] =' Статус'
L['Cancel (Shift)'] = 'Отмена (Shift)'
L['Waiting (Shift)'] = 'Ожидание (Shift)'
L['Disable Entry Button on Cancel'] = 'Отключить кнопку вступления при отмене'
L['Disables the entry button when the group leader cancels entry, hold shift to re-enable the button'] = 'Отключает возможность нажать на кнопку вступления, если лидер решил не вступать на БГ. Держите shift чтобы включить кнопку'
L['Disable Entry Button by Default'] = 'По умолчанию отключать кнопку входа'
L['The entry button requires shift to be held first, or the group leader to enter.'] = 'Кнопка вступления на БГ будет доступна лишь при зажатой клавише shift, или если лидер решил вступить на БГ'
L['Show or hide the Battleground Commander group information window'] = 'Спрятать или показать окно информации группы'
L['Queue Pop'] = 'Возможно вступление на БГ'
L['Accepted'] = 'Принято'
L['Role Check'] = 'Проверка ролей'
L['OK'] = 'ОК'
L['Offline'] = 'Вне сети'
L['Open World'] = 'Открытый мир'
L['Alterac Valley'] = 'Альтеракская долина'
L['Alterac Valley (Korrak\'s Revenge)'] = 'Альтеракская долина (Месть Коррака)'
L['Ashran'] = 'Ашран'
L['Battle for Wintergrasp'] = 'Битва на Озере Ледяных Оков'
L['Isle of Conquest'] = 'Остров Завоеваний'
L['Arathi Basin'] = 'Низина Арати'
L['Arathi Basin (Classic)'] = 'Низина Арати (классическая)'
L['Arathi Basin (Winter)'] = 'Низина Арати (зима)'
L['Arathi Basin Comp Stomp'] = 'Низина Арати (потасовка)'
L['Deepwind Gorge'] = 'Каньон Суровых Ветров'
L['Eye of the Storm'] = 'Око Бури'
L['Eye of the Storm (Rated)'] = 'Око Бури (рейтинговое)'
L['Isle of Conquest'] = 'Остров Завоеваний'
L['Seething Shore'] = 'Бурлящий берег'
L['Silvershard Mines'] = 'Сверкающие копи'
L['Strand of the Ancients'] = 'Берег Древних'
L['Temple of Kotmogu'] = 'Храм Котмогу'
L['The Battle for Gilneas'] = 'Битва за Гилнеас'
L['Twin Peaks'] = 'Два Пика'
L['Warsong Gulch'] = 'Ущелье Песни Войны'
L['Southshore vs. Tarren Mill'] = 'Потасовка на мельнице Таррен'
L['Queue Tools'] = 'Опции очереди'
L['Queue Inspection'] = 'Информация об очереди'
L['Notify When Paused'] = 'Уведомлять о паузе'
L['Send a chat message whenever the queue is paused'] = 'Отправлять сообщение в чат при паузе очереди'
L['Notify When Resumed'] = 'Уведомлять о возобновлении'
L['Send a chat message whenever the queue is resumed after being paused'] = 'Уведомлять о возобновлении очереди после паузы'
L['Ready Check on Pause'] = 'Проверка готовности при паузе'
L['Do a ready check whenever a queue pause is detected'] = 'Делать проверку готовности, если очередь встала на паузу'
L['Only as Leader or Assist'] = 'Только как лидер или помошник лидера'
L['Enable the queue pause detection features only when you are party leader or assist'] = 'Включить мониторинг паузы очереди только если вы лидер или помощник лидера'
L['Setup Automation'] = true
L['My raid mark'] = true
L['Automatically assign the configured raid mark when you become leader.'] = true
L['Do not mark me'] = true
L['Leader promotion sound'] = true
L['Play a sound when you are promoted or demoted from being raid leader.'] = true
L['Leader Setup'] = true
L['Requesting Lead'] = true
L['Players to automatically make assistant in raid'] = true
L['Target and run "%s" to add names'] = true
L['Select a target and then run /bgca to add them to the auto assist list'] = true
L['%s will now automatically be promoted to assistant in battlegrounds'] = true
L['Demote players not listed'] = true
L['When someone gets assistant, or was assistant when you get lead, it will automatically demote these players to member'] = true
L['Promote players listed'] = true
L['When someone in this list is in your battleground while you are leader, they will get promoted to assistant'] = true
L['Available Icons'] = true
L['Available Icons to automatically mark people with'] = true
L['Players to automatically mark with an icon in raid'] = true
L['Include assist list in marking'] = true
L['Also mark players with raid icons when listed in the list of automatic assists'] = true
L['Select a target and then run /bgcm to add them to the automatic marking list'] = true
L['%s will now automatically be marked in battlegrounds'] = true