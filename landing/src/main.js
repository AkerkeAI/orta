import './styles.css';

const navToggle = document.querySelector('.nav-toggle');
const nav = document.querySelector('.site-nav');
navToggle?.addEventListener('click', () => {
  const open = navToggle.getAttribute('aria-expanded') === 'true';
  navToggle.setAttribute('aria-expanded', String(!open));
  nav?.classList.toggle('is-open', !open);
});
document.querySelectorAll('.site-nav a').forEach((link) => link.addEventListener('click', () => {
  navToggle?.setAttribute('aria-expanded', 'false');
  nav?.classList.remove('is-open');
}));

const revealObserver = new IntersectionObserver((entries) => {
  entries.forEach((entry) => { if (entry.isIntersecting) { entry.target.classList.add('is-visible'); revealObserver.unobserve(entry.target); } });
}, { threshold: 0.12 });
document.querySelectorAll('.reveal').forEach((element) => revealObserver.observe(element));

const prompts = {
  interview: 'Объясни на английском, почему ты хочешь изучать эту специальность.',
  startup: 'Сделай 60-секундный питч своего проекта на английском.',
  meeting: 'Потренируй профессиональное представление себя.'
};
const promptText = document.querySelector('#prompt-text');
document.querySelectorAll('.prompt').forEach((button) => button.addEventListener('click', () => {
  document.querySelectorAll('.prompt').forEach((item) => item.classList.remove('active'));
  button.classList.add('active');
  promptText.textContent = prompts[button.dataset.prompt];
}));

const interestForm = document.querySelector('#interest-form');
const interestSubmit = document.querySelector('#interest-submit');
const formNote = document.querySelector('#form-note');
let interestSubmitting = false;

interestForm?.addEventListener('submit', async (event) => {
  event.preventDefault();
  if (interestSubmitting || !interestForm.reportValidity()) return;

  interestSubmitting = true;
  interestSubmit.disabled = true;
  interestSubmit.textContent = 'Отправка…';
  formNote.textContent = 'Отправляем email…';
  formNote.classList.remove('success', 'error');

  try {
    const response = await fetch(interestForm.action, {
      method: 'POST',
      body: new FormData(interestForm),
      headers: { Accept: 'application/json' }
    });

    if (!response.ok) throw new Error(`Formspree responded with ${response.status}`);
    formNote.textContent = 'Спасибо за интерес к ORTA. Email принят.';
    formNote.classList.add('success');
    interestForm.reset();
  } catch {
    formNote.textContent = 'Не удалось отправить email. Проверь соединение и попробуй ещё раз.';
    formNote.classList.add('error');
  } finally {
    interestSubmitting = false;
    interestSubmit.disabled = false;
    interestSubmit.innerHTML = 'Оставить интерес <span>↗</span>';
  }
});