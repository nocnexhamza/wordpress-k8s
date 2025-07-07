pipeline {
    agent any
    
    environment {
        DOCKER_REGISTRY = 'docker.io/your-registry' // Change to your registry
        WORDPRESS_APP_NAME = 'wordpress'
        MYSQL_APP_NAME = 'wordpress-mysql'
        K8S_NAMESPACE = 'wordpress'
        WORDPRESS_HOST = 'cpanel.nocnexus.com' // Change to your domain
    }
    
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', 
                url: 'https://github.com/nocnexushamza/wordpress-k8s.git' // Change to your repo
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
        
        stage('Deploy MySQL') {
            steps {
                script {
                    withKubeConfig([credentialsId: 'k8s-credentials']) {
                        // Create namespace if not exists
                        sh "kubectl create namespace ${K8S_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -"
                        
                        // Generate MySQL password if not exists
                        sh """
                            if ! kubectl -n ${K8S_NAMESPACE} get secret mysql-pass >/dev/null 2>&1; then
                                openssl rand -base64 20 | kubectl -n ${K8S_NAMESPACE} create secret generic mysql-pass --from-file=password=/dev/stdin
                            fi
                        """
                        
                        // Deploy MySQL
                        sh """
                            sed -e 's|{{MYSQL_APP_NAME}}|${MYSQL_APP_NAME}|g' \
                                -e 's|{{K8S_NAMESPACE}}|${K8S_NAMESPACE}|g' \
                                k8s/mysql-deployment.yaml > k8s/mysql-deployment-${env.BUILD_NUMBER}.yaml
                            
                            kubectl apply -f k8s/mysql-deployment-${env.BUILD_NUMBER}.yaml
                            kubectl apply -f k8s/mysql-service.yaml
                            kubectl rollout status -n ${K8S_NAMESPACE} deployment/${MYSQL_APP_NAME}
                        """
                    }
                }
            }
        }
        
        stage('Deploy WordPress') {
            steps {
                script {
                    withKubeConfig([credentialsId: 'k8s-credentials']) {
                        sh """
                            sed -e 's|{{WORDPRESS_APP_NAME}}|${WORDPRESS_APP_NAME}|g' \
                                -e 's|{{K8S_NAMESPACE}}|${K8S_NAMESPACE}|g' \
                                -e 's|{{DOCKER_REGISTRY}}|${DOCKER_REGISTRY}|g' \
                                -e 's|{{BUILD_NUMBER}}|${env.BUILD_NUMBER}|g' \
                                -e 's|{{WORDPRESS_HOST}}|${WORDPRESS_HOST}|g' \
                                -e 's|{{MYSQL_APP_NAME}}|${MYSQL_APP_NAME}|g' \
                                k8s/wordpress-deployment.yaml > k8s/wordpress-deployment-${env.BUILD_NUMBER}.yaml
                            
                            kubectl apply -f k8s/wordpress-deployment-${env.BUILD_NUMBER}.yaml
                            kubectl apply -f k8s/wordpress-service.yaml
                            kubectl apply -f k8s/wordpress-ingress.yaml
                            kubectl rollout status -n ${K8S_NAMESPACE} deployment/${WORDPRESS_APP_NAME}
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
                sh 'rm -f k8s/*-${env.BUILD_NUMBER}.yaml || true'
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