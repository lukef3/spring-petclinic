pipeline {
    agent any

    tools {
        maven 'Maven_3.9.9' // Jenkins maven installation
    }

    environment {
        GCLOUD_PROJECT_ID = 'petclinic-455414'
    }

    stages {
        stage('Checkout') {
            steps {
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
        stage('Docker Build') {
            steps {
                sh 'sudo docker build -t spring-petclinic:latest .'
            }
        }

        stage('Push Image to Google Container Registry') {
            steps {
                withCredentials([file(credentialsId: 'gcloud-creds', variable: 'GCLOUD_CREDS')]) {
                    sh 'gcloud version' // test print google cloud version
                    sh 'gcloud auth activate-service-account --key-file="$GCLOUD_CREDS"' // authenticate with service account with my credentials file
                    sh 'gcloud auth configure-docker'
                    sh 'docker tag spring-petclinic:latest gcr.io/${GCLOUD_PROJECT_ID}/spring-petclinic:latest'  // tag the built docker image with a repository tag. https://cloud.google.com/artifact-registry/docs/docker/pushing-and-pulling?hl=en#push-tagged
                    sh 'docker push gcr.io/${GCLOUD_PROJECT_ID}/spring-petclinic:latest'
                }
            }
        }

        stage('Deploy to Google Cloud Run'){
            steps{
                withCredentials([file(credentialsId: 'gcloud-creds', variable: 'GCLOUD_CREDS')]) {
                    sh 'gcloud auth activate-service-account --key-file="$GCLOUD_CREDS"' // authenticate with service account with my credentials file
                    sh 'gcloud run deploy spring-petclinic --image gcr.io/${GCLOUD_PROJECT_ID}/spring-petclinic:latest --project ${GCLOUD_PROJECT_ID} --region europe-west2 --allow-unauthenticated --port 8081'  // https://cloud.google.com/run/docs/deploying#gcloud
                }
            }
        }
    }

    post {
        always {
            junit '**/target/surefire-reports/*.xml' // Publish JUnit test results
        }
    }
}
