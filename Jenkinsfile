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
            }
        }
        stage('TF Validate'){
            steps{
                sh """
                    cd bld-01
                    terraform validate
                """
            }
        }
        stage('TF Plan'){
            steps{
                sh """
                    cd bld-01
                    terraform plan
                """
            }
        }
        stage('TF apply'){
         
            steps {
                script {
                    def userInput = input(id: 'confirm', message: 'Apply Terraform?', parameters: [ [$class: 'BooleanParameterDefinition', defaultValue: false, description: 'Apply terraform', name: 'confirm'] ])      
          
                }

            sh"""
                # Run terraorm apply
                cd bld-01
                terraform apply
            """
         }    
     
           
            
        }
 
    }
}