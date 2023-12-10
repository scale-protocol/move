publish:
	sui client publish --gas-budget 10000 --skip-dependency-verification --with-unpublished-dependencies ./scale
	sui client upgrade --gas-budget 10000 --upgrade-capability 0xdf4ab1e3276745f78482054f5b0675c7c40726ef07c074f3e0157a223c29466c ./
	sui client publish --gas-budget 100000000 --skip-dependency-verification .
upgrade:
	sui client upgrade --gas-budget 100000000 --upgrade-capability 0x1c87809adbc37391a3d7f996350fd569567dd0e9c8498280f4ae7db1b629c40d --skip-dependency-verification

	sui client upgrade --gas-budget 100000000 --upgrade-capability 0xda324cce1412c187ed4b4cd4bd4abde0f9bcefc161e92f5e2cbc725a20d9d39c --skip-dependency-verification