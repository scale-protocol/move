p?=0xa7a9970d83e4cd4bb07adff254fb30e91fc9d9de
k?=xxx
admin_cap?=0x697b729dd208653049c8038fd3bd7ed7c04bc2da
nft_factory?=0x9131163a967c6f94a85ae3a593353c2e5f0aedfe
list?=0x4ecc7fd12dce5d808aca46baf04632b0f3eb3cab
t?=0x7d79014936c3f287ec88360a222b3c2f0ca9fcdb::scale::SCALE
market?=0x011dc4d6c6e2af888f769a49c96a427d223c3bbc
coin?=0x7d79014936c3f287ec88360a222b3c2f0ca9fcdb
account?=0x3f93dc019d9dd1a7fadff2056b584cc22d370dae
scale_admin?=0xa21519248d63bc233a30b88c3c2b1ba82912cf6c
import:
	sui keytool import "xx" ed25519 "m/44'/784'/0'/0'/0'"
publish:
	sui client publish --gas-budget 10000 .
add_factory_mould:
	sui client call --package $(p) --module enter --function add_factory_mould --args $(admin_cap) $(nft_factory) '[115, 99, 97, 108, 101]' '[115, 99, 97, 108, 101, 32, 110, 102, 116, 32, 49, 54, 55, 50]' '[104, 116, 116, 112, 115, 58, 47, 47, 105, 112, 102, 115, 46, 105, 111, 47, 105, 112, 102, 115, 47, 98, 97, 102, 121, 98, 101, 105, 98, 105, 102, 120, 106, 120, 122, 108, 105, 122, 106, 103, 105, 108, 50, 111, 97, 108, 105, 107, 50, 55, 111, 116, 114, 54, 114, 105, 54, 100, 109, 105, 53, 122, 106, 118, 54, 118, 101, 120, 116, 106, 50, 97, 55, 109, 110, 52, 50, 119, 116, 121, 47, 49, 54, 55, 50, 46, 112, 110, 103]' --gas-budget 10000
createmarket:
	sui client call --package $(p) --module enter --function create_market --type-args $(t) --args $(list) $(coin) '[66, 84, 67, 47, 85, 83, 68]' '[66, 84, 67, 47, 85, 83, 68]' 1 100 $(coin) --gas-budget 10000
investment:
	sui client call --package $(p) --module enter --function investment --type-args $(p)::pool::Tag $(t) --args $(list) $(market) $(coin) $(nft_factory) '[115, 99, 97, 108, 101]' --gas-budget 10000
createaccount:
	# sui client call --package $(p) --module enter --function create_account --args  $(coin) --gas-budget 1000
	sui client call --function create_account --module in --package $(p) --type-args $(t) --args $(coin) --gas-budget 100000
deposit:
	sui client call --function deposit --module enter --package $(p) --type-args $(t) --args $(account) $(coin) 50000  --gas-budget 100000
openposition:
	sui client call --package $(p) --module enter --function open_position --type-args $(p)::pool::Tag $(t) --args $(list) $(market) $(account) 1 1 1 1 --gas-budget 10000
update_spread_fee:
	sui client call --package $(p) --module enter --function update_spread_fee --type-args $(p)::pool::Tag $(t) --args $(scale_admin) $(list) $(market) 100 true --gas-budget 10000