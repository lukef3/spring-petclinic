pipeline {
    agent any

    tools {
        maven 'Maven_3.9.9' // Jenkins maven installation
    }

    environment {
        GCLOUD_PROJECT_ID = 'petclinic-455414'
        INSTANCE_NAME = 'petclinic-vm'
        VM_REGION = 'europe-west2'
        VM_ZONE = 'europe-west2-c'
        VM_MACHINE_TYPE = 'e2-small'
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
        stage('Docker Build') {
            steps {
                sh 'docker build -t spring-petclinic:latest .'
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

        stage('Provision Google Compute Engine'){
            steps{
                dir('infra'){
                    withCredentials([
                            file(credentialsId: 'gcloud-creds', variable: 'GCLOUD_CREDS'),
                            string(credentialsId: 'ssh-user', variable: 'SSH_USER'),
                            string(credentialsId: 'service-account-email', variable: 'SERVICE_ACC_EMAIL')
                        ]) {
                        script {
                            env.GOOGLE_APPLICATION_CREDENTIALS = env.GCLOUD_CREDS
                             echo "Initializing Terraform..."
                             sh 'terraform init'
                             echo "Applying Terraform changes..."
                             sh """terraform apply -auto-approve \
                                  -var='gcp_project_id=${GCLOUD_PROJECT_ID}' \
                                  -var='service_account_email=${SERVICE_ACC_EMAIL}' \
                                  -var='instance_name=${INSTANCE_NAME}' \
                                  -var='vm_region=${VM_REGION}' \
                                  -var='vm_zone=${VM_ZONE}' \
                                  -var='machine_type=${VM_MACHINE_TYPE}' \
                                  -var='ssh_user=${SSH_USER}'"""
                         }
                    }
                }
            }
        }

        stage('Update GCE Docker Container') {
                steps {
                    script {
                        sleep time: 60, unit: 'SECONDS' // give the VM some time after provisioning
                        withCredentials([sshUserPrivateKey(credentialsId: 'petclinic-vm-ssh-key', keyFileVariable: 'SSH_PRIVATE_KEY', usernameVariable: 'SSH_USERNAME')]) {
                            // Get VM external IP
                            def IP = sh(script: "gcloud compute instances describe ${INSTANCE_NAME} --zone=${VM_ZONE} --project=${GCLOUD_PROJECT_ID} --format='value(networkInterfaces[0].accessConfigs[0].natIP)'", returnStdout: true).trim()
                            def command = """
                              gcloud auth configure-docker gcr.io -q
                              docker pull gcr.io/${GCLOUD_PROJECT_ID}/spring-petclinic:latest
                              docker stop spring-petclinic || true
                              docker rm spring-petclinic || true
                              docker run -d \
                                --name spring-petclinic \
                                -p 8081:8081 \
                                --restart always \
                                gcr.io/${GCLOUD_PROJECT_ID}/spring-petclinic:latest
                            """

                            sshCommand(
                                remote: [
                                    name: INSTANCE_NAME,
                                    host: IP,
                                    user: SSH_USERNAME,
                                    identityFile: SSH_PRIVATE_KEY,
                                    allowAnyHosts: true
                                ],
                                command: command
                            )
                        }
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
        success {
            slackSend (color: '#00FF00', message: "SUCCESSFUL: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})")
        }
        failure{
            slackSend (color: '#00FF00', message: "SUCCESSFUL: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})")
        }
    }
}
