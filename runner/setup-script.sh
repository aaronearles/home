REPO="https://github.com/aaronearles/home"
TOKEN=""

# Create a folder
mkdir actions-runner && cd actions-runner

# Download the latest runner package
# You can check for latest release version here: https://github.com/actions/runner/releases, would like to automate this to $LATEST
curl -o actions-runner-linux-x64-2.317.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.317.0/actions-runner-linux-x64-2.317.0.tar.gz

# Optional: Validate the hash
echo "9e883d210df8c6028aff475475a457d380353f9d01877d51cc01a17b2a91161d  actions-runner-linux-x64-2.317.0.tar.gz" | shasum -a 256 -c

# Extract the installer
tar xzf ./actions-runner-linux-x64-2.317.0.tar.gz

# Create the runner and start the configuration experience
./config.sh --url $REPO --token $TOKEN

# Last step, run it!
./run.sh

