from web3 import Web3
from eth_account import Account
import json

# Настройки
INFURA_URL = "https://eth-sepolia.g.alchemy.com/v2/oro5WXmsIS6bz5ri8a5Axp3cqmELoFPW"  # Замените на ваш URL
CONTRACT_ADDRESS = "0xdc1ecb9dbb04859fd81fbe5efb5ce766e9dabf4d"  # Адрес вашего развернутого контракта
PRIVATE_KEY_FILE = ".privateKey.txt"  # Файл с приватным ключом вашего кошелька
ABI_FILE = "DCAContract.json"  # ABI контракта

# Читаем приватный ключ вашего кошелька
with open(PRIVATE_KEY_FILE, "r") as f:
    user_private_key = f.read().strip()

# Инициализация Web3
web3 = Web3(Web3.HTTPProvider(INFURA_URL))
user_account = Account.from_key(user_private_key)

# Генерация нового depositAddress
new_account = Account.create()
deposit_address = new_account.address
deposit_private_key = new_account.key.hex()

# Сохраняем приватный ключ depositAddress в файл
with open(f"{deposit_address}_key.txt", "w") as f:
    f.write(deposit_private_key)

print(f"Generated depositAddress: {deposit_address}")
print(f"Private key saved to {deposit_address}_key.txt")

# Загрузка ABI контракта
with open(ABI_FILE, "r") as f:
    contract_abi = json.load(f)

# Инициализация контракта
contract = web3.eth.contract(address=Web3.to_checksum_address(CONTRACT_ADDRESS), abi=contract_abi)

# Параметры вызова createDCA
token_address = Web3.to_checksum_address("0xf08a50178dfcde18524640ea6618a1f965821715")  # Адрес токена
interval = 60  # Интервал в секундах
amount = web3.to_wei(0.0001, "ether")  # Количество токенов на один DCA
dca_type = 0  # 0 = BUY, 1 = SELL
total_iterations = 10  # Общее количество покупок

# Формирование транзакции
nonce = web3.eth.get_transaction_count(user_account.address)
transaction = contract.functions.createDCA(
    token_address,
    interval,
    amount,
    dca_type,
    deposit_address,
    total_iterations
).build_transaction({
    "chainId": 11155111,  # Замените на Chain ID вашей сети (например, 1 для Ethereum Mainnet)
    "gas": 300000,
    "gasPrice": web3.to_wei("30", "gwei"),
    "nonce": nonce
})

# Подписываем транзакцию
signed_tx = web3.eth.account.sign_transaction(transaction, private_key=user_private_key)

# Отправляем транзакцию
tx_hash = web3.eth.send_raw_transaction(signed_tx.raw_transaction)

print(f"Transaction sent! Hash: {tx_hash.hex()}")
