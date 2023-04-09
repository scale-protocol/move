publish:
	sui client publish --gas-budget 10000 --skip-dependency-verification --with-unpublished-dependencies ./scale
	sui client upgrade --gas-budget 10000 --upgrade-capability 0xdf4ab1e3276745f78482054f5b0675c7c40726ef07c074f3e0157a223c29466c ./
	sui client publish --gas-budget 10000 .