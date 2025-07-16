pipeline {
    agent any
    
    environment {
        DOCKER_REGISTRY = 'docker.io/nocnex' // Your Docker registry
        WORDPRESS_APP_NAME = 'wordpress'
        K8S_NAMESPACE = 'wordpress'
        WORDPRESS_HOST = 'wordpress.nocnexus.com' // Your domain
    }
    
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', 
                url: 'https://github.com/nocnexhamza/wordpress-k8s.git' // Your repo
            }
        }

        stage('SonarQube Analysis') {
            steps {
                script {
                    def scannerHome = tool 'SonarQubeScanner'
                    withSonarQubeEnv('SonarQube') {
                        sh """
                            ${scannerHome}/bin/sonar-scanner \
                            -Dsonar.projectKey=wordpress-project \
                            -Dsonar.sources=. \
                            -Dsonar.inclusions=**/*.js \
                            -Dsonar.exclusions=Dockerfile,wp-admin/**,wp-includes/** \
                            -Dsonar.sourceEncoding=UTF-8 \
                            -Dsonar.javascript.node.maxspace=8192
                        """
                    }
                }
            }
        }
        
        stage('Quality Gate') {
            steps {
                timeout(time: 1, unit: 'HOURS') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }      

        stage('Build WordPress Docker Image') {
            steps {
                script {
                    sh """
                        DOCKER_BUILDKIT=1 docker build \
                        -t ${DOCKER_REGISTRY}/${WORDPRESS_APP_NAME}:${env.BUILD_NUMBER} \
                        -f Dockerfile.wordpress .
                    """
                }
            }
        }

        stage('Scan with Trivy') {
            steps {
                script {
                    sh label: 'Trivy Scan', script: """
                        docker run --rm \
                            -v /var/run/docker.sock:/var/run/docker.sock \
                            -v "\${WORKSPACE}:/workspace" \
                            aquasec/trivy image \
                            --severity CRITICAL \
                            --format table \
                            --output /workspace/trivy-report.txt \
                            ${DOCKER_REGISTRY}/${WORDPRESS_APP_NAME}:${env.BUILD_NUMBER} || true
                    """
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-report.txt', allowEmptyArchive: true
                    publishHTML(target: [
                        allowMissing: true,
                        alwaysLinkToLastBuild: false,
                        keepAll: true,
                        reportDir: '.',
                        reportFiles: 'trivy-report.txt',
                        reportName: 'Trivy Report'
                    ])
                }
            }
        }

        stage('Push Docker Images') {
            steps {
                script {
                    withCredentials([usernamePassword(
                        credentialsId: 'docker-hub-credentials',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )]) {
                        sh """
                            echo \$DOCKER_PASS | docker login -u \$DOCKER_USER --password-stdin
                            docker push ${DOCKER_REGISTRY}/${WORDPRESS_APP_NAME}:${env.BUILD_NUMBER}
                        """
                    }
                }
            }
        }
        
        stage('Deploy WordPress and MySQL') {
            steps {
                script {
                    withKubeConfig([credentialsId: 'k8s-credentials']) {
                        // Create namespace if not exists
                        sh "kubectl create namespace ${K8S_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -"
                        
                        // Apply Kubernetes configurations
                        sh """
                            sed -e 's|{{WORDPRESS_APP_NAME}}|${WORDPRESS_APP_NAME}|g' \
                                -e 's|{{K8S_NAMESPACE}}|${K8S_NAMESPACE}|g' \
                                -e 's|{{DOCKER_REGISTRY}}|${DOCKER_REGISTRY}|g' \
                                -e 's|{{BUILD_NUMBER}}|${env.BUILD_NUMBER}|g' \
                                -e 's|{{WORDPRESS_HOST}}|${WORDPRESS_HOST}|g' \
                            k8s/wordpress-mysql-full.yaml > k8s/wordpress-mysql-full-${env.BUILD_NUMBER}.yaml
                            sed -e 's|{{WORDPRESS_HOST}}|${WORDPRESS_HOST}|g' \
                                -e 's|{{K8S_NAMESPACE}}|${K8S_NAMESPACE}|g' \
                            k8s/wordpress-ingress.yaml > k8s/wordpress-ingress-${env.BUILD_NUMBER}.yaml
                            kubectl apply -f k8s/wordpress-mysql-full-${env.BUILD_NUMBER}.yaml
                            kubectl apply -f k8s/wordpress-ingress-${env.BUILD_NUMBER}.yaml
                            kubectl rollout status -n ${K8S_NAMESPACE} deployment/wordpress
                            kubectl rollout status -n ${K8S_NAMESPACE} deployment/wordpress-mysql
                        """
                    }
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                script {
                    withKubeConfig([credentialsId: 'k8s-credentials']) {
                        sh """
                            kubectl get pods,svc,ing,pvc -n ${K8S_NAMESPACE}
                            echo "WordPress should be available at http://${WORDPRESS_HOST}"
                        """
                    }
                }
            }
        }
    }
    
    post {
        always {
            script {
                sh """
                    rm -f k8s/wordpress-mysql-full-${env.BUILD_NUMBER}.yaml k8s/wordpress-ingress-${env.BUILD_NUMBER}.yaml || true
                """
                cleanWs()
            }
        }
        success {
            script {
                if (env.SLACK_CHANNEL) {
                    slackSend(
                        color: "good",
                        message: "SUCCESS: WordPress deployed to ${WORDPRESS_HOST} in namespace ${K8S_NAMESPACE}",
                        channel: env.SLACK_CHANNEL
                    )
                }
            }
        }
        failure {
            script {
                if (env.SLACK_CHANNEL) {
                    slackSend(
                        color: "danger",
                        message: "FAILED: WordPress deployment in namespace ${K8S_NAMESPACE}",
                        channel: env.SLACK_CHANNEL
                    )
                }
            }
        }
    }
}
