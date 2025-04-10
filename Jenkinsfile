pipeline {
    agent any

    tools {
        maven 'Maven_3.9.9' // Jenkins maven installation
    }

    stages {
        stage('Checkout') {
            steps {
                slackSend (color: '#FFFF00', message: "STARTED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})")
                git url: 'https://github.com/lukef3/spring-petclinic.git', branch: 'main'
            }
        }
        stage('Build') {
            steps {
                withMaven(maven: 'Maven_3.9.9'){ // Run Maven command using withMaven from maven pipeline plugin
                    sh 'mvn clean install' // compile, test, and package the application
                }
            }
        }
        stage('Sonarqube Scan'){
            steps{
                withSonarQubeEnv(installationName: 'Sonarqube'){
                    sh 'mvn sonar:sonar'
                }
            }
        }
        stage('Sonarqube Quality Gate'){
            steps{
                waitForQualityGate abortPipeline: true // wait for scan results to return
            }
        }
        stage('Deploy to Local Web Server')
        {
            steps{
                sh 'java -jar ./target/spring-petclinic-*.jar'
            }
        }
    }

    post {
        always {
            junit '**/target/surefire-reports/*.xml' // Publish JUnit test results
        }
        success {
            slackSend (color: '#00FF00', message: "SUCCESSFUL: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})")
        }
        failure{
            slackSend (color: '#00FF00', message: "SUCCESSFUL: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})")
        }
    }
}



