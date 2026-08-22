// Jenkins pipeline for jk2-web: build the WASM engine + game module on the build server and deploy
// to the test app server. Never touches production (jk2.virtastic.app is a separate path).
//
// The job checks this repo out on the builder (Jenkins + Docker live there), so the workspace IS the
// synced tree — ci/jenkins/sync-to-builder.sh is only for the manual laptop-driven flow. config.env
// is gitignored and absent in a fresh checkout, so every value comes from `environment {}` below
// (env overrides config.env per the scripts' precedence).
pipeline {
  agent any
  options { timestamps(); disableConcurrentBuilds(); timeout(time: 60, unit: 'MINUTES') }
  environment {
    TAG       = 'jk2:test'
    NAME      = 'jk2-test'
    PORT      = '8082'
    TEST_HOST = 'user@<test-host>'
    SSH_KEY   = '/var/jenkins_home/.ssh/jk2-deploy'   // builder->test key, lives on the builder
    SMOKE_URL = 'https://jk2.dev.virtastic.app'
  }
  stages {
    stage('Build')  { steps { sh 'SRC="$WORKSPACE" TAG="$TAG" ci/jenkins/build-engine.sh' } }
    stage('Deploy') { steps { sh 'ci/jenkins/deploy-test.sh' } }
    stage('Smoke') {
      steps {
        // Prefer the public origin once DNS + ingress exist; until then smoke-test the container
        // directly on the test host so the stage is meaningful from day one.
        sh '''
          if [ -n "$SMOKE_URL" ] && curl -sf -o /dev/null --max-time 8 "$SMOKE_URL/" 2>/dev/null; then
            ci/jenkins/smoke-test.sh "$SMOKE_URL"
          else
            echo "public origin not reachable yet; smoke-testing the container directly"
            ci/jenkins/smoke-test.sh "http://<test-host>:$PORT"
          fi
        '''
      }
    }
  }
  post {
    success { echo "jk2 built and deployed to the test server on :${env.PORT}" }
    failure { echo 'jk2 test pipeline failed — see stage logs' }
  }
}
