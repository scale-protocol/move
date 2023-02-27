k?=xx
p?=0x7d79014936c3f287ec88360a222b3c2f0ca9fcdb
reserve?=0xc612b7e57db806258b0323d57dc1d5530aab3a24
admin_cap?=0x750f039767e14491868cb6fb236a98a6a1c5dc23
set:
	sui client call --package $(p) --module scale --function set_subscription_ratio  --args $(admin_cap) $(reserve) 100 --gas-budget 1000 --json
airdrop:
	sui client call --package $(p) --module scale --function airdrop --args $(reserve) 0x9afaef1f63ce364758684675db5b77d727f0465a '100000' --gas-budget 1000
burn:
	sui client call --package $(p) --module scale --function burn --args $(reserve) 0x412c8314feb17cf45dbee2c271af0461dc536814 --gas-budget 1000
import:
	sui keytool import "$(k)" ed25519 "m/44'/784'/0'/0'/0'"
publish:
	sui client publish --gas-budget 10000 .