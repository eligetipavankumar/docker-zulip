pipeline {
    agent any

    environment {
        REGISTRY = "docker.io"
        IMAGE_NAME = "eligetipavankumar/zulipapp"
        IMAGE_TAG = "latest"
        KUBECONFIG = "C:/kube/config"   // safer path without spaces
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/eligetipavankumar/docker-zulip.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    bat 'docker build -t %IMAGE_NAME%:%IMAGE_TAG% .'
                }
            }
        }

        stage('Push to DockerHub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'DOCKER_USER', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    bat """
                        echo %DOCKER_PASS% | docker login -u %DOCKER_USER% --password-stdin
                        docker push %IMAGE_NAME%:%IMAGE_TAG%
                    """
                }
            }
        }

        stage('Deploy to Minikube') {
            steps {
                script {
                    bat """
                        echo Applying Kubernetes manifests...
                        kubectl apply -f k8s\\namespace.yaml
                        kubectl apply -f k8s\\postgres.yaml
                        kubectl apply -f k8s\\memcached.yaml
                        kubectl apply -f k8s\\rabbitmq.yaml
                        kubectl apply -f k8s\\redis.yaml
                        kubectl apply -f k8s\\deployment.yaml

                        echo Waiting for Zulip pod to be ready...
                        kubectl rollout status deployment/zulip -n zulip
                        kubectl get svc -n zulip
                    """
                }
            }
        }
    }
}
