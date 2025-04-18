pipeline {
    agent any

    environment {
        DOCKER_IMAGE = 'miriama13/foyer-app'
        DOCKER_TAG = 'latest'
        SONARQUBE_URL = 'http://172.20.99.98:9000'
        NEXUS_URL = 'http://172.20.99.98:8081/repository/maven-releases/'
        ARTIFACT_VERSION = "0.0.1-${BUILD_NUMBER}"
        ARTIFACT_NAME = 'Foyer'
        ARTIFACT_PATH = "tn/esprit/spring/${ARTIFACT_NAME}/${ARTIFACT_VERSION}/${ARTIFACT_NAME}-${ARTIFACT_VERSION}.jar"
        EMAIL_CREDENTIALS = credentials('email') // ID du credential
    }

    stages {
        stage('Checkout Code') {
            steps {
                git branch: 'mariem-tlili',
                    credentialsId: 'TOKEN',
                    url: 'https://github.com/Miriama130/devops-1.git'
            }
}
    
        stage('Clean Docker Environment') {
    steps {
        sh '''
            # Stop and remove all containers from the compose file
            docker-compose -f docker-compose.yml down --remove-orphans --volumes || true
            
            # Remove specific containers by name if they still exist
            docker rm -f spring-foyer mysql-container || true
            
            # Remove old images
            docker rmi -f ${DOCKER_IMAGE}:${DOCKER_TAG} || true
            
            # Clean up any dangling resources
            docker system prune -f
        '''
    }
}


        stage('Build & Test') {
            steps {
                sh 'mvn clean package'
            }
             post {
                always {
                    jacoco(
                        execPattern: 'target/jacoco.exec',
                        classPattern: 'target/classes',
                        sourcePattern: 'src/main/java',
                        exclusionPattern: 'src/test*',
                        changeBuildStatus: true,
                        minimumInstructionCoverage: '70',
                        maximumInstructionCoverage: '80'
                    )
                }
            }
        }

     stage('SonarQube Analysis') {
            steps {
                withCredentials([string(credentialsId: 'sonarqubetoken', variable: 'SONAR_TOKEN')]) {
                    sh '''
                        mvn sonar:sonar \
                        -Dsonar.projectKey=FoyerApp \
                        -Dsonar.host.url=${SONARQUBE_URL} \
                        -Dsonar.login=${SONAR_TOKEN}
                         -Dsonar.jacoco.reportPaths=target/jacoco.exec

                    '''
                }
            }
        }
        
      stage('Deploy to Nexus') {
    steps {
        script {
            withCredentials([usernamePassword(
                credentialsId: 'nexus',
                usernameVariable: 'NEXUS_USER',
                passwordVariable: 'NEXUS_PASS'
            )]) {
                sh '''
                    # Conversion de version
                    mvn versions:set -DnewVersion=${ARTIFACT_VERSION}
                    
                    # Déploiement avec settings.xml existant
                    mvn -B deploy \
                        -DaltDeploymentRepository=nexus-releases::default::${NEXUS_URL}${NEXUS_REPO_PATH} \
                        -s settings.xml
                '''
            }
        }
    }
}

        stage('Download Artifact from Nexus') {
            steps {
                script {
                    withCredentials([usernamePassword(
                        credentialsId: 'nexus',
                        usernameVariable: 'NEXUS_USER',
                        passwordVariable: 'NEXUS_PASS'
                    )]) {
                        sh 'mkdir -p target'
                        sh """
                            curl -u ${NEXUS_USER}:${NEXUS_PASS} \
                            -o target/${ARTIFACT_NAME}-${ARTIFACT_VERSION}.jar \
                            "${NEXUS_URL}${ARTIFACT_PATH}"
                        """
                        sh 'ls -l target/'
                    }
                }
            }
        }



        stage('Prepare Docker Artifacts') {
            steps {
                script {
                    def jarFile = "target/${ARTIFACT_NAME}-${ARTIFACT_VERSION}.jar"
                    sh """
                        [ -f ${jarFile} ] || exit 1
                        cp -v ${jarFile} target/Foyer-0.0.1.jar
                        ls -lh target/
                    """
                }
            }
        }

        stage('Build Docker Image') {
            environment {
                DOCKER_BUILDKIT = "1"
            }
            steps {
                sh """
                    docker build \
                        --progress=plain \
                        -t ${DOCKER_IMAGE}:${DOCKER_TAG} .
                    docker images | grep ${DOCKER_IMAGE}
                """
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockercredentials', 
                    usernameVariable: 'DOCKER_USERNAME', 
                    passwordVariable: 'DOCKER_PASSWORD'
                )]) {
                    sh """
                        set +x
                        echo ${DOCKER_PASSWORD} | docker login -u ${DOCKER_USERNAME} --password-stdin
                        set -x
                        docker push ${DOCKER_IMAGE}:${DOCKER_TAG}
                        docker logout
                    """
                }
            }
        }

        stage('Deploy Application') {
            steps {
                sh """
                    docker-compose -f docker-compose.yml down || true
                    docker-compose -f docker-compose.yml up -d
                """
            }
        }
    


        stage('Send Email') {
            steps {
                script {
                    emailext (
                        subject: "✅ Build Réussi : ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                        body: """
                            <p>Bonjour,</p>
                            <p>Le build du job <strong>${env.JOB_NAME}</strong> a réussi 🎉</p>
                            <p>Voir les détails ici : <a href="${env.BUILD_URL}">${env.BUILD_URL}</a></p>
                        """,
                        mimeType: 'text/html',
                        to: 'mariemtlili1999@gmail.com',
                        from: "${EMAIL_CREDENTIALS_USR}",
                        replyTo: "${EMAIL_CREDENTIALS_USR}"
                    )
                }
            }
        }
    }

   post {
        success {
            echo "Pipeline executed successfully!"
            echo "Artifacts deployed to Nexus: ${NEXUS_URL}"
            echo "Docker Image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
            echo "Application deployed at: http://172.20.99.98:8082/Foyer"
        }

        failure {
            echo "Pipeline failed. Check the logs for errors."
        }
    }

}
