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
                    cd bld-01
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
                    cd bld-01
                    terraform plan
                """
               
                sh 'gcloud auth list'
                sh 'gcloud container clusters get-credentials wordspres-gke-euwe2 --region europe-west2 --project flash-keel-412418'
                sh 'kubectl get ns'
            }
        }
        stage('TF apply'){
         
        steps {
        script {
           def userInput = input(id: 'confirm', message: 'Apply Terraform?', parameters: [ [$class: 'BooleanParameterDefinition', defaultValue: false, description: 'Apply terraform', name: 'confirm'] ])      
          
           }

        sh"""

            cd bld-01
            terraform plan
        """
         }    
     
           
            
        }
 
    }
}