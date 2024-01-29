pipeline{
    agent any
    stages{
        stage('Checkout'){
            steps{
                echo 'Checking out branch' + env.BRANCH_NAME
                checkout scm
                sh 'ls -lrt'
                
            }
        }
        stage('TF Initialize'){
            steps{
                sh """
                    cd bld-01
                    terraform init
                """
               
                sh 'gcloud auth list'
                sh 'gcloud container clusters get-credentials wordspres-gke-euwe2 --region europe-west2 --project flash-keel-412418'
                sh 'kubectl get ns'
            }
        }
        stage('TF Validate'){
            steps{
                sh """
                    terraform validate
                """
               
                sh 'gcloud auth list'
                sh 'gcloud container clusters get-credentials wordspres-gke-euwe2 --region europe-west2 --project flash-keel-412418'
                sh 'kubectl get ns'
            }
        }
        stage('TF Plan'){
            steps{
                sh """
                    ls -lrt 
                    terraform plan
                """
               
                sh 'gcloud auth list'
                sh 'gcloud container clusters get-credentials wordspres-gke-euwe2 --region europe-west2 --project flash-keel-412418'
                sh 'kubectl get ns'
            }
        }
 
    }
}