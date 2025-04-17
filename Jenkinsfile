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
        }

     stage('SonarQube Analysis') {
    steps {
        withCredentials([string(credentialsId: 'sonarqubetoken', variable: 'SONAR_TOKEN')]) {
            sh '''
                mvn -B sonar:sonar \
                    -Dsonar.projectKey=FoyerApp \
                    -Dsonar.host.url=${SONARQUBE_URL} \
                    -Dsonar.login=${SONAR_TOKEN} \
                    -Dsonar.qualitygate.wait=true
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
            // Vérification explicite du fichier JAR
            def jarFiles = findFiles(glob: 'target/Foyer-*.jar')
            if (jarFiles.isEmpty()) {
                error("Aucun fichier JAR trouvé dans target/")
            }
            
            // Utilisation du dernier fichier JAR généré
            def jarFile = jarFiles.last().path
            echo "Fichier JAR utilisé : ${jarFile}"
            
            // Copie avec vérification
            sh """
                cp -v ${jarFile} target/Foyer-0.0.1.jar || exit 1
                ls -lh target/Foyer-*.jar
                [ -f target/Foyer-0.0.1.jar ] || exit 1
            """
        }
    }
}

stage('Build Docker Image') {
    environment {
        DOCKER_BUILDKIT = "1"  # Active les fonctionnalités modernes de Docker
    }
    steps {
        script {
            // Build avec cache et sortie détaillée
            sh """
                docker build \
                    --progress=plain \
                    --no-cache \
                    -t ${DOCKER_IMAGE}:${DOCKER_TAG} .
            """
            
            // Vérification de l'image
            sh """
                docker image inspect ${DOCKER_IMAGE}:${DOCKER_TAG} >/dev/null
                docker images --filter=reference="${DOCKER_IMAGE}:${DOCKER_TAG}"
            """
        }
    }
}

stage('Push to Docker Hub') {
    steps {
        withCredentials([usernamePassword(
            credentialsId: 'dockercredentials', 
            usernameVariable: 'DOCKER_USERNAME', 
            passwordVariable: 'DOCKER_PASSWORD'
        )]) {
            script {
                // Login avec timeout
                sh """
                    set +x  # Désactive l'affichage des commandes
                    echo ${DOCKER_PASSWORD} | \
                    timeout 60 docker login \
                        -u ${DOCKER_USERNAME} \
                        --password-stdin || exit 1
                    set -x
                """
                
                // Push avec retry en cas d'échec réseau
                retry(3) {
                    timeout(time: 5, unit: 'MINUTES') {
                        sh """
                            docker push ${DOCKER_IMAGE}:${DOCKER_TAG}
                        """
                    }
                }
                
                // Nettoyage sécurisé
                sh """
                    docker logout
                    unset DOCKER_USERNAME
                    unset DOCKER_PASSWORD
                """
            }
        }
    }
}

stage('Prepare Ports') {
    steps {
        script {
            // Nettoyage des containers existants
            sh '''
                docker-compose -f docker-compose.yml down || true
                docker stop ${DOCKER_IMAGE} || true
                docker rm ${DOCKER_IMAGE} || true
                
                # Nettoyage des volumes
                docker volume rm dockerimage_mysql_data || true
                docker volume prune -f || true
            '''
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
