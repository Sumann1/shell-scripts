#!/bin/bash

function usage {
  cat <<EOF
  USAGE:  $0 [-h] [-i image_id] [-i type] [-s sg] [-k ssh_key] [-p iam_profile]
  eg,
          $0 -h                #usage
          $0                   #query last n images then let user select
          $0 -i ami-123e45     #use ami-12345
EOF
  exit
}

function die {
  # die with a message
  echo >&2 "$@"
  exit 1
}


function is_ami_exist {
  local ami_id="$1"
  local region_name="$2"
  echo "checking if $ami_id exist"
  local output=$(aws ec2 describe-images \
    --filters \
    Name=image-id,Values=$ami_id \
    --query "Images[*].[CreationDate,ImageId,Name]" \
    --region "$region_name" \
    --output text)

  return $(echo "$output"| wc -l)
}

while getopts "hi:t:s:p:k:r:" o; do
  case "$o" in
    h) usage ;;
    i) opt_i=1; ami_id="$OPTARG" ;;
    r) opt_r=1; region="$OPTARG" ;;
    t) opt_t=1; type="$OPTARG" ;;
    s) opt_s=1; sg="$OPTARG" ;;
    k) opt_k=1; ssh_key="$OPTARG" ;;
    p) opt_p=1; iam_profile="$OPTARG" ;;
    *) usage ;;
  esac
done

region="${region:-us-east-1}"
type="${type:-t2.micro}"
sg="${sg:-sg-09856e72956d7d5dc}"
ssh_key="${ssh_key:-amzlinux2}"
iam_profile="${iam_profile:-Arn=arn:aws:iam::479379427248:instance-profile/adminrole}"
ami_id="${ami_id:-ami-0dfcb1ef8550277af}"
subnet_id="${subnet_id:-subnet-003d573d46408608e}"

echo "$type, $sg, $ssh_key, $iam_profile, $ami_id, $region"


if [ "$opt_i" == "1" ]; then
  # cli input with imageid
  is_ami_exist $ami_id $region && die "image doesnot exist"
else
  account_id=$(aws sts get-caller-identity --query "Account" --output text)
  echo "Latest AMI owned by current account: $ami_id"
fi

echo "Create a ec2 in subnet : " $subnet_id

ec2_id=$(aws ec2 run-instances --image-id $ami_id \
        --count 1 --instance-type $type --key-name $ssh_key \
        --security-group-ids $sg \
        --iam-instance-profile $iam_profile \
        --region "$region" \
        --subnet-id "$subnet_id" \
        --network-interfaces '[ { "DeviceIndex": 0, "DeleteOnTermination": true, "AssociatePublicIpAddress": true } ]' \
        --output text --query 'Instances[*].InstanceId')

echo "EC2 Id:" $ec2_id
aws ec2 create-tags --region $region --resources $ec2_id --tags Key=Name,Value=\"devops-public-ec2\"
echo "Waiting for instance to run"
aws ec2 wait instance-running --instance-ids "$ec2_id"
echo "EC2 $ec2_id is now running"


