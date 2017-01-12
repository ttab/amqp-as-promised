@Library("common") _

node {

  stage('checkout') {
    checkout scm
    sh "git clean -d -f -x"
  }

  docker.image('node:boron').inside {
    stage('npm install') {
      sh 'npm install'
    }

    stage('mocha') {
      sh '''
npm install mocha-jenkins-reporter
JUNIT_REPORT_PATH=test-results.xml ./node_modules/.bin/mocha -R mocha-jenkins-reporter || true
'''
      junit "test-results.xml"
    }
  }

}
