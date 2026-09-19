import 'package:flutter/widgets.dart';

import 'localization_service.dart';
import '../models/life_context.dart';

extension OrtaSemanticLocalization on AppLocalizations {
  String ui(String key) {
    const en = {
      'home': 'HOME',
      'plan': 'PLAN',
      'life': 'LIFE',
      'progress': 'PROGRESS',
      'day': 'Day',
      'week': 'Week',
      'timeline': 'TIMELINE',
      'today': 'TODAY',
      'life_map': 'LIFE MAP',
      'moments': 'MOMENTS',
      'practice_environment': 'Practice environment',
      'no_moments': 'No moments yet.',
      'add_moment': 'Add moment',
      'close': 'Close',
      'reset': 'Reset ORTA',
      'add_language': 'Add language goal',
      'open_language': 'Open Language ORTA',
    };
    const ru = {
      'home': 'ГЛАВНАЯ',
      'plan': 'ПЛАН',
      'life': 'ЖИЗНЬ',
      'progress': 'ПРОГРЕСС',
      'day': 'День',
      'week': 'Неделя',
      'timeline': 'РАСПИСАНИЕ',
      'today': 'СЕГОДНЯ',
      'life_map': 'КАРТА ЯЗЫКА',
      'moments': 'МОМЕНТЫ',
      'practice_environment': 'Среда практики',
      'no_moments': 'Моментов пока нет.',
      'add_moment': 'Добавить момент',
      'close': 'Закрыть',
      'reset': 'Сбросить ORTA',
      'add_language': 'Добавить цель языка',
      'open_language': 'Открыть Language ORTA',
    };
    const kk = {
      'home': 'БАСТЫ БЕТ',
      'plan': 'ЖОСПАР',
      'life': 'ӨМІР',
      'progress': 'ПРОГРЕСС',
      'day': 'Күн',
      'week': 'Апта',
      'timeline': 'КҮН ТӘРТІБІ',
      'today': 'БҮГІН',
      'life_map': 'ТІЛ КАРТАСЫ',
      'moments': 'СӘТТЕР',
      'practice_environment': 'Практика ортасы',
      'no_moments': 'Әзірге сәттер жоқ.',
      'add_moment': 'Сәт қосу',
      'close': 'Жабу',
      'reset': 'ORTA-ны қалпына келтіру',
      'add_language': 'Тіл мақсатын қосу',
      'open_language': 'Language ORTA ашу',
    };
    return (locale == AppLocale.russian
            ? ru
            : locale == AppLocale.kazakh
            ? kk
            : en)[key] ??
        key;
  }

  String lifeArea(LifeArea area) {
    const values = {
      AppLocale.english: [
        'School student',
        'University student',
        'Working',
        'Self-employed / Freelancer',
        'Building a business or project',
        'Gap year',
        'Other',
      ],
      AppLocale.russian: [
        'Школьник',
        'Студент университета',
        'Работаю',
        'Самозанятый / Фрилансер',
        'Развиваю бизнес или проект',
        'Год перерыва',
        'Другое',
      ],
      AppLocale.kazakh: [
        'Мектеп оқушысы',
        'Университет студенті',
        'Жұмыс істеймін',
        'Өзін-өзі жұмыспен қамтыған / Фрилансер',
        'Бизнес немесе жоба құрып жатырмын',
        'Gap year',
        'Басқа',
      ],
    };
    return values[locale]![area.index];
  }

  String lifeDomain(String key) {
    final domainKey =
        {
          'school': 'education',
          'university': 'education',
          'work': 'career',
          'freelance': 'career',
          'project': 'project',
          'gapYear': 'personal',
          'other': 'personal',
        }[key] ??
        key;
    final labels = locale == AppLocale.russian
        ? {
            'education': 'Образование',
            'career': 'Карьера',
            'project': 'Проекты',
            'language': 'Языки',
            'personal': 'Личные цели',
          }
        : locale == AppLocale.kazakh
        ? {
            'education': 'Білім',
            'career': 'Мансап',
            'project': 'Жобалар',
            'language': 'Тілдер',
            'personal': 'Жеке мақсаттар',
          }
        : {
            'education': 'Education',
            'career': 'Career',
            'project': 'Projects',
            'language': 'Languages',
            'personal': 'Personal goals',
          };
    return labels[domainKey] ?? domainKey;
  }

  String goal(String key) {
    const en = {
      'school_university': 'Get into university',
      'school_grades': 'Improve grades',
      'school_exams': 'Prepare for exams',
      'school_language': 'Learn a language',
      'school_time': 'Organize my time',
      'university_performance': 'Improve academic performance',
      'university_graduate': 'Graduate successfully',
      'university_internship': 'Find an internship',
      'university_research': 'Find research opportunities',
      'university_job': 'Find a job',
      'university_language': 'Learn a language',
      'university_time': 'Organize my time',
      'career_advance': 'Advance my career',
      'career_job': 'Find a new job',
      'career_skills': 'Build professional skills',
      'career_certification': 'Earn a certification',
      'career_organization': 'Improve work-life organization',
      'freelance_clients': 'Find clients',
      'freelance_income': 'Increase income',
      'freelance_portfolio': 'Improve portfolio',
      'freelance_workload': 'Manage workload',
      'freelance_business': 'Build a business',
      'project_develop': 'Develop my project',
      'project_funding': 'Find grants or funding',
      'project_partners': 'Find partners',
      'project_users': 'Find users or customers',
      'project_mvp': 'Build an MVP or product',
      'project_pitch': 'Improve my pitch',
      'gap_university': 'Prepare for university',
      'gap_portfolio': 'Build a portfolio',
      'gap_work': 'Work',
      'gap_travel': 'Travel',
      'gap_language': 'Learn a language',
      'gap_skills': 'Develop skills',
      'gap_project': 'Build a project',
      'other_personal': 'Make progress in my current situation',
      'other_goal': 'Other goal',
    };
    const ru = {
      'school_university': 'Поступить в университет',
      'school_grades': 'Улучшить оценки',
      'school_exams': 'Подготовиться к экзаменам',
      'school_language': 'Изучать язык',
      'school_time': 'Организовать время',
      'university_performance': 'Улучшить успеваемость',
      'university_graduate': 'Успешно закончить университет',
      'university_internship': 'Найти стажировку',
      'university_research': 'Найти исследовательские возможности',
      'university_job': 'Найти работу',
      'university_language': 'Изучать язык',
      'university_time': 'Организовать время',
      'career_advance': 'Развить карьеру',
      'career_job': 'Найти новую работу',
      'career_skills': 'Развить профессиональные навыки',
      'career_certification': 'Получить сертификат',
      'career_organization': 'Улучшить организацию работы и жизни',
      'freelance_clients': 'Найти клиентов',
      'freelance_income': 'Увеличить доход',
      'freelance_portfolio': 'Улучшить портфолио',
      'freelance_workload': 'Управлять нагрузкой',
      'freelance_business': 'Построить бизнес',
      'project_develop': 'Развить проект',
      'project_funding': 'Найти гранты или финансирование',
      'project_partners': 'Найти партнёров',
      'project_users': 'Найти пользователей или клиентов',
      'project_mvp': 'Создать MVP или продукт',
      'project_pitch': 'Улучшить презентацию',
      'gap_university': 'Подготовиться к университету',
      'gap_portfolio': 'Создать портфолио',
      'gap_work': 'Работать',
      'gap_travel': 'Путешествовать',
      'gap_language': 'Изучать язык',
      'gap_skills': 'Развить навыки',
      'gap_project': 'Создать проект',
      'other_personal': 'Продвинуться в текущей ситуации',
      'other_goal': 'Другая цель',
    };
    const kk = {
      'school_university': 'Университетке түсу',
      'school_grades': 'Бағаларды жақсарту',
      'school_exams': 'Емтихандарға дайындалу',
      'school_language': 'Тіл үйрену',
      'school_time': 'Уақытты ұйымдастыру',
      'university_performance': 'Оқу үлгерімін жақсарту',
      'university_graduate': 'Университетті сәтті аяқтау',
      'university_internship': 'Тағылымдама табу',
      'university_research': 'Зерттеу мүмкіндіктерін табу',
      'university_job': 'Жұмыс табу',
      'university_language': 'Тіл үйрену',
      'university_time': 'Уақытты ұйымдастыру',
      'career_advance': 'Мансапты дамыту',
      'career_job': 'Жаңа жұмыс табу',
      'career_skills': 'Кәсіби дағдыларды дамыту',
      'career_certification': 'Сертификат алу',
      'career_organization': 'Жұмыс пен өмірді ұйымдастыру',
      'freelance_clients': 'Клиенттер табу',
      'freelance_income': 'Табысты арттыру',
      'freelance_portfolio': 'Портфолионы жақсарту',
      'freelance_workload': 'Жүктемені басқару',
      'freelance_business': 'Бизнес құру',
      'project_develop': 'Жобаны дамыту',
      'project_funding': 'Грант немесе қаржы табу',
      'project_partners': 'Серіктестер табу',
      'project_users': 'Пайдаланушылар немесе клиенттер табу',
      'project_mvp': 'MVP немесе өнім жасау',
      'project_pitch': 'Презентацияны жақсарту',
      'gap_university': 'Университетке дайындалу',
      'gap_portfolio': 'Портфолио жасау',
      'gap_work': 'Жұмыс істеу',
      'gap_travel': 'Саяхаттау',
      'gap_language': 'Тіл үйрену',
      'gap_skills': 'Дағдыларды дамыту',
      'gap_project': 'Жоба құру',
      'other_personal': 'Қазіргі жағдайымда алға жылжу',
      'other_goal': 'Басқа мақсат',
    };
    return (locale == AppLocale.russian
            ? ru
            : locale == AppLocale.kazakh
            ? kk
            : en)[key] ??
        key;
  }

  String interpretation(String key) {
    const en = {
      'gap_year': 'Gap year',
      'preparing_university': 'Preparing for university',
      'portfolio_development': 'Portfolio development',
      'work_experience': 'Work experience',
      'project_development': 'Project development',
      'personal_development': 'Personal development',
    };
    const ru = {
      'gap_year': 'Год перерыва',
      'preparing_university': 'Подготовка к университету',
      'portfolio_development': 'Развитие портфолио',
      'work_experience': 'Опыт работы',
      'project_development': 'Развитие проекта',
      'personal_development': 'Личное развитие',
    };
    const kk = {
      'gap_year': 'Gap year',
      'preparing_university': 'Университетке дайындық',
      'portfolio_development': 'Портфолионы дамыту',
      'work_experience': 'Жұмыс тәжірибесі',
      'project_development': 'Жобаны дамыту',
      'personal_development': 'Жеке даму',
    };
    return (locale == AppLocale.russian
            ? ru
            : locale == AppLocale.kazakh
            ? kk
            : en)[key] ??
        key;
  }
}

AppLocalizations ortaLocalizations(BuildContext context) =>
    AppLocalizations.of(context);
