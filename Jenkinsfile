@Library("common") _

node {

  stage('checkout') {
    checkout scm
    sh "git clean -d -f -x"
  }

  docker.image('node:erbium').inside {
    stage('npm install') {
      sh 'npm install'
    }

    stage('mocha') {
      try {
        sh 'JUNIT_REPORT_PATH=test-results.xml ./node_modules/.bin/mocha -R mocha-jenkins-reporter'
      } finally {
        junit "test-results.xml"
      }
    }

    stage('lint') {
      try {
        sh './node_modules/.bin/coffeelint src --reporter checkstyle > checkstyle.xml'
      } finally {
        checkstyle pattern: 'checkstyle.xml'
      }
    }
  }

}
