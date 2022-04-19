#!/bin/bash

PULP_NAMESPACE=${PULP_NAMESPACE:-"pulp"}
PULP_HOST=${PULP_HOST:-"pulp-web-svc"}
PULP_ROUTE=${PULP_ROUTE:-"pulp"}
PULP_PORT=${PULP_PORT:-"24880"}
PULP_ADMIN_PASSWORD_SECRET=${PULP_ADMIN_PASSWORD_SECRET:-"pulp-admin-password"}
PULP_APP_ROOT=${PULP_APP_ROOT:-"pulp"}
PULP_API_VERSION=${PULP_API_VERSION:-"v3"}
PULP_HTTP_PROTOCOL=${PULP_HTTP_PROTOCOL:-"http"}
PULP_USER_CONTAINER="rfe-publisher-container"
PULP_USER_FILE="rfe-publisher-file"
PULP_USER_RPM="rfe-publisher-rpm"
PULP_USER_OSTREE="rfe-publisher-ostree"
PULP_USERS=($PULP_USER_CONTAINER $PULP_USER_FILE $PULP_USER_RPM $PULP_USER_OSTREE)
PULP_ROLE_CONTAINER="rfe-container"
PULP_CONTAINER_NAMESPACE="rfe"
PULP_CONTAINER_NAMESPACE_OWNER_ROLE="container.containernamespace_owner"
RFE_NAMESPACE=${RFE_NAMESPACE:-"rfe"}
RFE_PULP_DOCKERCONFIGJSON_SECRET=${RFE_PULP_DOCKERCONFIGJSON_SECRET:-"publisher"}

PULP_ROLE_CONTAINER_BODY=$(cat <<EOF
{
  "name": "${PULP_ROLE_CONTAINER}",
  "description": "Manage Container Content",
  "permissions": [
      "container.add_blob",
      "container.change_blob",
      "container.delete_blob",
      "container.view_blob",
      "container.add_blobmanifest",
      "container.change_blobmanifest",
      "container.delete_blobmanifest",
      "container.view_blobmanifest",
      "container.add_containerdistribution",
      "container.change_containerdistribution",
      "container.delete_containerdistribution",
      "container.pull_containerdistribution",
      "container.push_containerdistribution",
      "container.view_containerdistribution",
      "container.add_containernamespace",
      "container.change_containernamespace",
      "container.delete_containernamespace",
      "container.namespace_add_containerdistribution",
      "container.namespace_change_containerdistribution",
      "container.namespace_change_containerpushrepository",
      "container.namespace_delete_containerdistribution",
      "container.namespace_modify_content_containerpushrepository",
      "container.namespace_pull_containerdistribution",
      "container.namespace_push_containerdistribution",
      "container.namespace_view_containerdistribution",
      "container.namespace_view_containerpushrepository",
      "container.view_containernamespace",
      "container.add_containerpushrepository",
      "container.change_containerpushrepository",
      "container.delete_containerpushrepository",
      "container.modify_content_containerpushrepository",
      "container.view_containerpushrepository",
      "container.add_containerremote",
      "container.change_containerremote",
      "container.delete_containerremote",
      "container.view_containerremote",
      "container.add_containerrepository",
      "container.build_image_containerrepository",
      "container.change_containerrepository",
      "container.delete_containerrepository",
      "container.delete_containerrepository_versions",
      "container.modify_content_containerrepository",
      "container.sync_containerrepository",
      "container.view_containerrepository",
      "container.add_contentredirectcontentguard",
      "container.change_contentredirectcontentguard",
      "container.delete_contentredirectcontentguard",
      "container.view_contentredirectcontentguard",
      "container.add_manifest",
      "container.change_manifest",
      "container.delete_manifest",
      "container.view_manifest",
      "container.add_manifestlistmanifest",
      "container.change_manifestlistmanifest",
      "container.delete_manifestlistmanifest",
      "container.view_manifestlistmanifest",
      "container.add_tag",
      "container.change_tag",
      "container.delete_tag",
      "container.view_tag",
      "container.add_upload",
      "container.change_upload",
      "container.delete_upload",
      "container.view_upload"
  ]
}
EOF
)

PULP_BASE="${PULP_HTTP_PROTOCOL}://${PULP_HOST}:${PULP_PORT}"
PULP_API="$PULP_BASE/${PULP_APP_ROOT}/api/${PULP_API_VERSION}"

echo "Waiting for Pulp to be active..."
while true; do

  PULP_STATUS_RESPONSE=$(curl -s -k -w '%{http_code}' -o /dev/null -L ${PULP_API}/status)

  if [[ $PULP_STATUS_RESPONSE -eq 200 ]]; then
    break
  else
    sleep 5
  fi

done

echo "Getting Pulp Route"
PULP_ROUTE_HOST=$(oc -n ${PULP_NAMESPACE} get route ${PULP_ROUTE} -o jsonpath='{.spec.host}')


if [[ -z ${PULP_USERNAME} ]] || [[ -z ${PULP_PASSWORD} ]]; then
  echo "Getting Pulp Username and Password"
  PULP_USERNAME="admin"
  PULP_PASSWORD=$(oc get secrets -n ${PULP_NAMESPACE} ${PULP_ADMIN_PASSWORD_SECRET} -o jsonpath='{.data.password}' | base64 -d)
fi

# Create Users
PULP_USER_LIST_RESPONSE="$(curl -s -k -L -u ${PULP_USERNAME}:${PULP_PASSWORD} ${PULP_API}/users/)"

for username in ${PULP_USERS[@]}; do
  echo
  echo "Username: ${username}"
  username_first_name=$(echo ${username} | cut -f1-2 -d-)
  username_last_name=$(echo ${username} | cut -f3 -d-)
  username_email="${username}@redhat.com"

  USERNAME_COUNT=$(echo "${PULP_USER_LIST_RESPONSE}" | jq --arg username "${username}" -r '[.results[] | select(.username==$username)] | length')
  USERNAME_REQUEST="{\"username\": \"${username}\",\"password\": \"${username}\",\"first_name\": \"${username_first_name}\",\"last_name\": \"${username_last_name}\",\"email\": \"${username_email}\"}"
  if [[ "${USERNAME_COUNT}" == 0 ]]; then
    echo "Creating user $username"

    CREATE_USER_RESPONSE_CODE=$(curl -s -k -w '%{http_code}' -o /dev/null -L -u ${PULP_USERNAME}:${PULP_PASSWORD} -X POST -H "Content-Type: application/json" -d  "$USERNAME_REQUEST" ${PULP_API}/users/)
    
    if [ $CREATE_USER_RESPONSE_CODE -ne 201 ]; then
      echo "Unexpected status from User creation. Username: ${username}. Status Code: ${CREATE_USER_RESPONSE_CODE}"
      exit 1
    fi
  
  elif [[ "${USERNAME_COUNT}" == 1 ]]; then
    echo "Updating user $username"
    
    USER_HREF=$(echo "${PULP_USER_LIST_RESPONSE}" | jq --arg username "${username}" -r '.results[] | select(.username==$username).pulp_href')

    UPDATE_USER_RESPONSE_CODE=$(curl -s -k -w '%{http_code}' -o /dev/null -L -u ${PULP_USERNAME}:${PULP_PASSWORD} -X PUT -H "Content-Type: application/json" -d  "$USERNAME_REQUEST" ${PULP_BASE}${USER_HREF})
    
    if [ $UPDATE_USER_RESPONSE_CODE -ne 200 ]; then
      echo "Unexpected status from User update. Username: ${username}. Status Code: ${UPDATE_USER_RESPONSE_CODE}"
      exit 1
    fi

  fi

done

# Create Container Namespace
PULP_CONTAINER_NAMESPACE_LIST_RESPONSE="$(curl -s -k -L -u ${PULP_USERNAME}:${PULP_PASSWORD} ${PULP_API}/pulp_container/namespaces/)"
NAMESPACE_REQUEST="{\"name\": \"${PULP_CONTAINER_NAMESPACE}\"}"

NAMESPACE_HREF=$(echo "${PULP_CONTAINER_NAMESPACE_LIST_RESPONSE}" | jq --arg name "${PULP_CONTAINER_NAMESPACE}" -r '.results[] | select(.name==$name).pulp_href')

if [[ "${NAMESPACE_HREF}" == "" ]]; then
  echo
  echo "Creating Container Namespace $PULP_CONTAINER_NAMESPACE"

  NAMESPACE_HREF=$(curl -s -k -L -u ${PULP_USERNAME}:${PULP_PASSWORD} -X POST -H "Content-Type: application/json" -d  "$NAMESPACE_REQUEST" ${PULP_API}/pulp_container/namespaces/ | jq -r '.pulp_href')
  
  if [ $NAMESPACE_HREF == "" ]; then
    echo "Unexpected status from Container Namespace creation. Namespace: ${PULP_CONTAINER_NAMESPACE}."
    exit 1
  fi
fi

# Get Container User
PULP_USER_LIST_RESPONSE="$(curl -s -k -L -u ${PULP_USERNAME}:${PULP_PASSWORD} ${PULP_API}/users/)"
PULP_USER_CONTAINER_ID=$(echo "${PULP_USER_LIST_RESPONSE}" | jq --arg username "${PULP_USER_CONTAINER}" -r '.results[] | select(.username==$username).id')

PULP_USER_CONTAINER_ROLES=$(curl -s -k -L -u ${PULP_USERNAME}:${PULP_PASSWORD} -H "Content-Type: application/json" ${PULP_API}/users/${PULP_USER_CONTAINER_ID}/roles/)
PULP_USER_CONTAINER_OWNER_ROLE_COUNT=$(echo "${PULP_USER_CONTAINER_ROLES}" | jq --arg role "${PULP_CONTAINER_NAMESPACE_OWNER_ROLE}" -r '[.results[] | select(.role==$role)] | length')

if [[ "${PULP_USER_CONTAINER_OWNER_ROLE_COUNT}" == 0 ]]; then

  echo
  echo "Adding ${PULP_USER_CONTAINER} as owner in namespace ${PULP_CONTAINER_NAMESPACE}"

  NAMESPACE_OWNER_ROLE_REQUEST="{\"role\": \"${PULP_CONTAINER_NAMESPACE_OWNER_ROLE}\",\"content_object\": \"${NAMESPACE_HREF}\"}"
  NAMESPACE_OWNER_ROLE_REQUEST_RESPONSE_CODE=$(curl -s -k -w '%{http_code}' -o /dev/null -L -u ${PULP_USERNAME}:${PULP_PASSWORD} -X POST -H "Content-Type: application/json" -d  "$NAMESPACE_OWNER_ROLE_REQUEST" ${PULP_API}/users/${PULP_USER_CONTAINER_ID}/roles/)

  if [ $NAMESPACE_OWNER_ROLE_REQUEST_RESPONSE_CODE -ne 201 ]; then
    echo "Unexpected status from Role Association to User. Status Code: ${NAMESPACE_OWNER_ROLE_REQUEST_RESPONSE_CODE}"
    exit 1
  fi

fi

# Create Pull Secret in RFE Namespace
echo
echo "Setting Pulp Pull Secret in '${RFE_NAMESPACE}' namespace"
kubectl create secret docker-registry -n ${RFE_NAMESPACE} ${RFE_PULP_DOCKERCONFIGJSON_SECRET} --docker-server=${PULP_ROUTE_HOST} --docker-username=${PULP_USERNAME} --docker-password=${PULP_PASSWORD} -o yaml --dry-run=client | oc apply -f-




# Ignore the rest

exit

PULP_GROUPS_LIST_RESPONSE="$(curl -s -k -L -u ${PULP_USERNAME}:${PULP_PASSWORD} ${PULP_API}/groups/)"
PULP_CONTAINER_RFE_GROUP_ID=$(echo "${PULP_GROUPS_LIST_RESPONSE}" | jq --arg name "container.namespace.owners.${PULP_CONTAINER_NAMESPACE}" -r '.results[] | select(.name==$name).id')

if [[ "${PULP_CONTAINER_RFE_GROUP_ID}" == "" ]]; then
  echo "Could not find ${PULP_CONTAINER_NAMESPACE} Group ID"
  exit 1
fi

echo
echo "Adding ${PULP_USER_CONTAINER} to group"

USER_GROUP_ADD_REQUEST="{\"username\": \"${PULP_USER_CONTAINER}\"}"
CREATE_USER_CONTAINER_GROUP_RESPONSE_CODE=$(curl -s -k -w '%{http_code}' -o /dev/null -L -u ${PULP_USERNAME}:${PULP_PASSWORD} -X POST -H "Content-Type: application/json" -d  "$USER_GROUP_ADD_REQUEST" ${PULP_API}/groups/${PULP_CONTAINER_RFE_GROUP_ID}/users/)

if [ $CREATE_USER_CONTAINER_GROUP_RESPONSE_CODE -ne 201 ]; then
  echo "Unexpected status from User Association to Group. Status Code: ${CREATE_USER_CONTAINER_GROUP_RESPONSE_CODE}"
  exit 1
fi


exit 0
# Create Roles
PULP_ROLE_LIST_RESPONSE="$(curl -s -k -L -u ${PULP_USERNAME}:${PULP_PASSWORD} ${PULP_API}/roles/)"

PULP_ROLE_CONTAINER_COUNT=$(echo "${PULP_ROLE_LIST_RESPONSE}" | jq --arg name "${PULP_ROLE_CONTAINER}" -r '[.results[] | select(.name==$name)] | length')

if [[ "${PULP_ROLE_CONTAINER_COUNT}" == 0 ]]; then
  echo "Creating container role $PULP_ROLE_CONTAINER"

  CREATE_ROLE_CONTAINER_RESPONSE_CODE=$(curl -s -k -w '%{http_code}' -o /dev/null -L -u ${PULP_USERNAME}:${PULP_PASSWORD} -X POST -H "Content-Type: application/json" -d  "$PULP_ROLE_CONTAINER_BODY" ${PULP_API}/roles/)

  if [ $CREATE_ROLE_CONTAINER_RESPONSE_CODE -ne 201 ]; then
    echo "Unexpected status from Container Role creation. Status Code: ${CREATE_ROLE_CONTAINER_RESPONSE_CODE}"
    exit 1
  fi

elif [[ "${PULP_ROLE_CONTAINER_COUNT}" == 1 ]]; then

  echo "Updating container role $PULP_ROLE_CONTAINER"

  ROLE_HREF=$(echo "${PULP_ROLE_LIST_RESPONSE}" | jq --arg name "${PULP_ROLE_CONTAINER}" -r '.results[] | select(.name==$name).pulp_href')

  UPDATE_ROLE_CONTAINER_RESPONSE_CODE=$(curl -s -k -w '%{http_code}' -o /dev/null -L -u ${PULP_USERNAME}:${PULP_PASSWORD} -X PUT -H "Content-Type: application/json" -d  "$PULP_ROLE_CONTAINER_BODY" ${PULP_BASE}${ROLE_HREF})

  if [ $UPDATE_ROLE_CONTAINER_RESPONSE_CODE -ne 200 ]; then
    echo "Unexpected status from Container Role update. Status Code: ${UPDATE_ROLE_CONTAINER_RESPONSE_CODE}"
    exit 1
  fi

fi