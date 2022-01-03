@Library("common") _

node {

  stage('checkout') {
    checkout scm
    sh "git clean -d -f -x"
  }

  docker.image('node:gallium').inside {
    stage('npm install') {
      sh 'npm install'
    }

    stage('mocha') {
      try {
        sh 'JUNIT_REPORT_PATH=test-results.xml ./node_modules/.bin/mocha -R mocha-jenkins-reporter'
      } finally {
        recordIssues(
          enabledForFailure: true,
          tools: [
            junitParser(pattern: 'test-results.xml')
          ]
        )
        mineRepository()
      }
    }

    stage('lint') {
      try {
        sh './node_modules/.bin/coffeelint src --reporter checkstyle > checkstyle.xml'
      } finally {
        recordIssues(
          enabledForFailure: true,
          tools: [
            checkStyle(pattern: 'checkstyle.xml')
          ]
        )
      }
    }
  }

}
