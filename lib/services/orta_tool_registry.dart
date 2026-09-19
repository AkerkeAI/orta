enum OrtaToolAccess { read, write }

class OrtaToolDefinition {
  final String name;
  final OrtaToolAccess access;
  const OrtaToolDefinition(this.name, this.access);
}

class OrtaToolRegistry {
  static const tools = <OrtaToolDefinition>[
    OrtaToolDefinition('getLifeContext', OrtaToolAccess.read),
    OrtaToolDefinition('getCurrentScreenContext', OrtaToolAccess.read),
    OrtaToolDefinition('getPlan', OrtaToolAccess.read),
    OrtaToolDefinition('findFreeTime', OrtaToolAccess.read),
    OrtaToolDefinition('proposeCalendarEvent', OrtaToolAccess.write),
    OrtaToolDefinition('proposeStudyPlan', OrtaToolAccess.write),
    OrtaToolDefinition('addGoal', OrtaToolAccess.write),
    OrtaToolDefinition('updateGoal', OrtaToolAccess.write),
    OrtaToolDefinition('addExam', OrtaToolAccess.write),
    OrtaToolDefinition('addUniversity', OrtaToolAccess.write),
    OrtaToolDefinition('updateUniversity', OrtaToolAccess.write),
    OrtaToolDefinition('addProject', OrtaToolAccess.write),
    OrtaToolDefinition('updateProject', OrtaToolAccess.write),
    OrtaToolDefinition('openLanguageOrta', OrtaToolAccess.read),
    OrtaToolDefinition('createApplicationDraft', OrtaToolAccess.write),
    OrtaToolDefinition('webSearch', OrtaToolAccess.read),
    OrtaToolDefinition('openWebResult', OrtaToolAccess.read),
    OrtaToolDefinition('verifySource', OrtaToolAccess.read),
    OrtaToolDefinition('searchEmail', OrtaToolAccess.read),
    OrtaToolDefinition('readEmail', OrtaToolAccess.read),
    OrtaToolDefinition('draftEmail', OrtaToolAccess.write),
    OrtaToolDefinition('sendEmail', OrtaToolAccess.write),
    OrtaToolDefinition('readCalendar', OrtaToolAccess.read),
    OrtaToolDefinition('createEvent', OrtaToolAccess.write),
    OrtaToolDefinition('openURL', OrtaToolAccess.read),
    OrtaToolDefinition('researchPage', OrtaToolAccess.read),
  ];
}
