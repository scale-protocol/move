p?=0x5119916ca0be7abbaab4577f7a36533e2c2c9bb0
k?=xxx
admin_cap?=0x56befce222d92902caf90a28a89d2bfa0b53d669
scale_nft_factory?=0xa9a35a79b481834923f1fc63f139e7dec2684349
list?=0xaa8bb75a15b25963dd419e65f3e701925cfb8013
t?=0x8cdb687d949d63cd95d6e404edfc47ccfbb83070::scale::SCALE
market?=0x491f14074efefb590a8041eeee52ff4a4dcbdefd
coin?=0x16d1d6881437d8812a9aae1f328fa72293cc9da2
account?=0xaf10e2034561f1550fd6097922a67962bc161771
import:
	sui keytool import "xx" ed25519 "m/44'/784'/0'/0'/0'"
publish:
	sui client publish --gas-budget 10000 .
add_factory_mould:
	sui client call --package $(p) --module in --function add_factory_mould --args $(admin_cap) $(scale_nft_factory) '[115, 99, 97, 108, 101]' '[115, 99, 97, 108, 101, 32, 110, 102, 116, 32, 49, 54, 55, 50]' '[104, 116, 116, 112, 115, 58, 47, 47, 105, 112, 102, 115, 46, 105, 111, 47, 105, 112, 102, 115, 47, 98, 97, 102, 121, 98, 101, 105, 98, 105, 102, 120, 106, 120, 122, 108, 105, 122, 106, 103, 105, 108, 50, 111, 97, 108, 105, 107, 50, 55, 111, 116, 114, 54, 114, 105, 54, 100, 109, 105, 53, 122, 106, 118, 54, 118, 101, 120, 116, 106, 50, 97, 55, 109, 110, 52, 50, 119, 116, 121, 47, 49, 54, 55, 50, 46, 112, 110, 103]' --gas-budget 10000
createmarket:
	sui client call --package $(p) --module in --function create_market --type-args $(t) --args $(list) $(coin) '[66, 84, 67, 47, 85, 83, 68]' '[66, 84, 67, 47, 85, 83, 68]' 1 $(scale_coin) --gas-budget 10000
investment:
	sui client call --package $(p) --module in --function investment --type-args $(p)::pool::PoolSign $(t) --args $(list) $(market) $(coin) $(scale_nft_factory) '[115, 99, 97, 108, 101]' --gas-budget 10000
createaccount:
	# sui client call --package $(p) --module in --function create_account --args  $(coin) --gas-budget 1000
	sui client call --function create_account --module in --package $(p) --type-args $(t) --args $(coin) --gas-budget 100000
deposit:
	sui client call --function deposit --module in --package $(p) --type-args $(t) --args $(account) $(coin) 50000  --gas-budget 100000
openposition:
	sui client call --package $(p) --module in --function open_position --type-args $(p)::pool::PoolSign $(t) --args $(list) $(market) $(account) 1 1 1 1 --gas-budget 10000