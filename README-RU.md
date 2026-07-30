# Emoji Legacy Patch — безопасное исследование

Это самостоятельный проект, не связанный с Telegraphica. Он не содержит и не скачивает `Apple Color Emoji.ttc` — шрифт остаётся только у владельца macOS 26.

Текущий режим разработки — **additive-only**: штатный
`/System/Library/Fonts/Apple Color Emoji.ttf` не заменяется. Инструмент
`build-additions.command` сравнивает `cmap` пользовательского шрифта macOS 26
со штатным шрифтом старой ОС и формирует список только отсутствующих code
points. Полный TTC MavericksForever не используется как payload.

## Важное ограничение

Пока тесты не выполнены **отдельно** на OS X 10.8.5 и 10.9.5 (Intel), проект не заявляет поддержку эмодзи macOS 26. Старый CoreText может не прочитать формат современного TTC или не применить GSUB/ZWJ-лигатуры. Скрипт анализирует `sbix`, `cmap`, `GSUB` и перед установкой запускает CoreText-проверку одиночного символа, tone modifier, флага, семейной и профессиональной ZWJ-последовательностей и VS16. Это проверка покрытия, но не замена визуального теста.

## Порядок работы на тестовом Mac

1. Только read-only: зафиксируйте `sw_vers`, `uname -m`, пути Character Palette и результаты `./verify.command`.
2. Получите donor исключительно с собственного тома macOS 26 и штатный legacy font с принадлежащей вам старой ОС. Выполните `./build-payload.command --font "/Volumes/Имя/System/Library/Fonts/Apple Color Emoji.ttc" --legacy-font "/путь/Apple Color Emoji.ttf"`. Полный donor TTC в payload не копируется. Зеркала и неизвестные бинарники запрещены.
3. Сборка вычисляет отсутствующие code points, исключает служебные ASCII/ZWJ/variation/modifier/tag mappings, извлекает первый TTC face, заменяет `cmap` и `name`, сохраняет `sbix` и создаёт отдельный `Emoji26 Additions.ttf`. Затем CoreText проверяет новые glyphs и отсутствие старого `U+1F600`.
4. После валидации запустите `./install.command` и введите `ADDITIONS`. Скрипт устанавливает только `/Library/Fonts/Emoji26 Additions.ttf`; системный Apple font и Character Palette не изменяются.
5. Перезагрузите Mac и вручную проверьте в TextEdit: `🫨`, `👍🏽`, `🇺🇦`, `👨‍👩‍👧`, `👩‍⚕️`, `❤️`. Убедитесь, что TextEdit и Character Palette не падают. Успешная установка не равна успешному рендерингу.
6. Откат: `./uninstall.command`, введите `REMOVE-ADDITIONS`, затем перезагрузите. Скрипт не удаляет cache-каталоги и не трогает Apple font.

Для создания одного приватного установочного файла выполните
`./build-pkg.command`. Результат `dist/Emoji26-Additions-0.2.0.pkg` содержит
derived Apple glyph data и предназначен только владельцу исходной установки
macOS — публиковать или коммитить этот `.pkg` нельзя.

## Character Palette

На Mavericks сначала только просмотрите `/System/Library/Input Methods/CharacterPalette.app/Contents/Resources/`: `Category-Emoji.plist`, `CharacterDB.sqlite3` и локализованные ресурсы. Их автоматическое изменение намеренно отсутствует: схема и поведение должны быть подтверждены на 10.9.5. На Mountain Lion пути сначала выявляются read-only на реальной машине; до этого доступен лёгкий отдельный picker: `./build-picker.command` (копирует выбранный символ в буфер).

Исходная исследовательская работа: [Updated Mavericks Emojis](https://github.com/Wowfunhappy/Updated-Mavericks-Emojis). По сообщениям автора, старый Mavericks picker имеет ограничения для tone variants и поиска; это нельзя выдавать за полную поддержку.

Статический разбор пакета MavericksForever и отличия принятого здесь подхода:
[`research/MAVERICKSFOREVER.md`](research/MAVERICKSFOREVER.md).

`build-pkg.command` собирает локальный `.pkg` после создания payload. Source-only
архив не содержит Apple font binaries.
