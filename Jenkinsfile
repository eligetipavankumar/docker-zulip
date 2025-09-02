pipeline {
    agent any

    environment {
        REGISTRY = "docker.io"                // Docker Hub registry
        IMAGE_NAME = "your-dockerhub-username/zulip"
        IMAGE_TAG = "11.0"
        KUBECONFIG = "$HOME/.kube/config"     // Minikube kubeconfig
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/zulip/zulip.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    sh 'docker build -t $IMAGE_NAME:$IMAGE_TAG .'
                }
            }
        }

        stage('Push to DockerHub') {
            steps {
                withCredentials([usernamePassword(credentialsId: '	DOCKER_USER', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push $IMAGE_NAME:$IMAGE_TAG
                    '''
                }
            }
        }

        stage('Deploy to Minikube') {
            steps {
                script {
                    sh '''
                        kubectl apply -f k8s/namespace.yaml
                        kubectl apply -f k8s/postgres.yaml
                        kubectl apply -f k8s/memcached.yaml
                        kubectl apply -f k8s/rabbitmq.yaml
                        kubectl apply -f k8s/redis.yaml
                        kubectl apply -f k8s/zulip.yaml
                    '''
                }
            }
        }
    }
}
