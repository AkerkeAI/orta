# Публикация ORTA: Vercel + Render

В проекте Flutter Web-приложение и отдельный Node API. Vercel собирает сайт, Render запускает API. Файлы vercel.json и render.yaml готовят обе части. Миграции Supabase для этого развёртывания не нужны.

## 1. Опубликовать API на Render

1. В Render выберите New → Blueprint и подключите AkerkeAI/orta.
2. Выберите ветку feat/personal-academy-modes, где находятся файлы развёртывания.
3. Render найдёт render.yaml и создаст orta-api.
4. Введите GROQ_API_KEY, SUPABASE_PUBLISHABLE_KEY и TAVILY_API_KEY в Render. Секреты остаются на сервере.
5. После сборки откройте URL Render-сервиса. Проверка /health должна вернуть {"status":"ok"}.

## 2. Собрать приложение на Vercel

1. В Vercel выберите Add New → Project и подключите AkerkeAI/orta.
2. Выберите ветку feat/personal-academy-modes. Если Vercel сейчас показывает main, измените Production Branch в Project Settings → Git после создания проекта или запустите preview-развёртывание нужной ветки.
3. Укажите корневую папку репозитория (./), а Framework Preset — Other. Не выбирайте отдельный сервис landing или backend: это не Flutter-приложение.
4. В Vercel Environment Variables добавьте для Production и Preview:
   - SUPABASE_URL — URL проекта Supabase.
   - SUPABASE_PUBLISHABLE_KEY — публичный publishable key Supabase.
   - ORTA_BACKEND_URL — URL Render из шага 1, например https://orta-api.onrender.com.
5. Нажмите Deploy. Vercel использует vercel.json, устанавливает Flutter stable SDK, собирает build/web и публикует приложение.

## 3. Разрешить запросы сайта

1. Скопируйте точный адрес опубликованного сайта Vercel, например https://orta-....vercel.app.
2. В Render откройте orta-api → Environment и добавьте ORTA_ALLOWED_ORIGINS со значением адреса сайта без завершающего /. Для нескольких адресов используйте список через запятую. Сохраните изменения, чтобы Render перезапустил API.
3. В Supabase откройте Authentication → URL Configuration и добавьте адрес сайта в Redirect URLs. Для Vercel-поддоменов можно добавить шаблон https://*.vercel.app/**. Укажите production-домен как Site URL, если появится постоянный домен.
4. Обновите ORTA. Проверка /health должна отвечать status: ok. AI-запросы принимаются только с действующей сессией ORTA.

## Заметки

- Каталог landing — отдельная Vite-страница. Импорт только landing опубликует лендинг, а не приложение.
- В Vercel добавляются только Supabase publishable key и публичный адрес Render. Секреты Groq и Tavily вводятся в Render.
- Render free-сервис может засыпать после простоя, поэтому первый запрос после паузы иногда занимает дольше.
