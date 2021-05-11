String getDevDepsXml() {
  return '''
<component name="libraryTable">
  <library name="dev-deps">
    <CLASSES>
      <root url="file://\$PROJECT_DIR\$/.rush/dev-deps" />
    </CLASSES>
    <JAVADOC />
    <SOURCES />
    <jarDirectory url="file://\$PROJECT_DIR\$/.rush/dev-deps" recursive="false" />
  </library>
</component>
''';
}

String getDepsXml() {
  return '''
<component name="libraryTable">
  <library name="deps">
    <CLASSES>
      <root url="file://\$PROJECT_DIR\$/deps" />
    </CLASSES>
    <JAVADOC />
    <SOURCES />
    <jarDirectory url="file://\$PROJECT_DIR\$/deps" recursive="false" />
  </library>
</component>
''';
}

String getIml() {
  return '''
<?xml version="1.0" encoding="UTF-8"?>
<module type="JAVA_MODULE" version="4">
  <component name="NewModuleRootManager" inherit-compiler-output="true">
    <exclude-output />
    <content url="file://\$MODULE_DIR\$">
      <sourceFolder url="file://\$MODULE_DIR\$/src" isTestSource="false" />
    </content>
    <orderEntry type="inheritedJdk" />
    <orderEntry type="sourceFolder" forTests="false" />
    <orderEntry type="library" name="dev-deps" level="project" />
    <orderEntry type="library" name="deps" level="project" />
  </component>
</module>
''';
}

String getMiscXml() {
  return '''
<?xml version="1.0" encoding="UTF-8"?>
<project version="4">
  <component name="ProjectRootManager" version="2" languageLevel="JDK_8" project-jdk-name="8" project-jdk-type="JavaSDK">
    <output url="file://\$PROJECT_DIR\$/classes" />
  </component>
</project>
''';
}

String getModulesXml(String name) {
  return '''
<?xml version="1.0" encoding="UTF-8"?>
<project version="4">
  <component name="ProjectModuleManager">
    <modules>
      <module fileurl="file://\$PROJECT_DIR\$/$name.iml" filepath="\$PROJECT_DIR\$/$name.iml" />
    </modules>
  </component>
</project>
''';
}