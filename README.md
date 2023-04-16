## Motif - Asset

1. Install, build, test repo
	yarn
	yarn build
	yarn test
2. Deploy contracts to blockchain
	remove the contract addresses from addresses/7018.json
	update .env.rod with private key and rpc
	yarn deploy --chainId 7018
	yarn deploy --chainId 7019
	check if addresses/7018.json filled with addresses
3. Deploy library to npm
	update package.json with the next version and username
	npm login (if not logged in) 
	//make sure you did yarn build, blue text has to be long!
	npm pack  
	npm publish --access=public 
	// if not works NPM_TOKEN=x npm publish --access=public
 