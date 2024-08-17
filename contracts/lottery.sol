// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract lottery is ERC20, Ownable (msg.sender) {
    address public contractNFT;
    address public winner; // Dirección usuario ganador
    mapping(address => address) public user_contract; // Registro del usuario

    constructor() ERC20("Lottery", "DR") {
        _mint(address(this), 1000);
        contractNFT = address(new mainERC721());
    }

    // Precio de los tokens ERC-20
    function priceTokens(uint256 _numTokens) internal pure returns (uint256) {
        return _numTokens * 1 ether; // 1 ether = 10 ** 18
    }

    // Visualización balance tokens ERC-20 de un usuario
    function balanceTokens(address _owner) public view returns (uint256) {
        return balanceOf(_owner); // Balance tokens ERC 20 de un usuario
    }

    function balanceTokensSC() public view returns (uint256) {
        return balanceOf(address(this)); // Balance tokens ERC 20 del contrato
    }

    function balanceEthersSC() public view returns (uint256) {
        return address(this).balance / 10**18; // Balance Ether del contrato
    }

    function mint(uint256 _amount) public onlyOwner {
        _mint(address(this), _amount); // Mint tokens ERC 20 del contrato
    }

    // REgistro de usuarios
    function register() internal {
        address addr_personal_contract = address(new ticketsNFTs(msg.sender, address(this), contractNFT));
        require(addr_personal_contract != address(0), "Failed to create ticketsNFTs contract");
        user_contract[msg.sender] = addr_personal_contract;
    }

    function usersInfo(address _account) public view returns (address) {
        return user_contract[_account]; // Información de los usuarios
    }

    event TokenTransfer(address from, address to, uint256 amount);

    function buyTokensERC20(uint256 _numTokens) public payable {

        if(user_contract[msg.sender] == address(0)) {
            register(); // Registro de los usuarios del contrato (Owner)
        }

        uint256 cost = priceTokens(_numTokens);
        require(msg.value >= cost, "Not enough ether"); // Verificar que el usuario haya ingresado Ether suficiente para comprar tokens ERC 20
        
        uint256 balance_before = balanceTokensSC(); // Balance tokens ERC 20 antes de comprar tokens ERC 20
        require(_numTokens <= balance_before, "Buy less tokens");
        
        emit TokenTransfer(address(this), msg.sender, _numTokens);
        uint256 returnValue = msg.value - cost;
        payable(msg.sender).transfer(returnValue); // Envio ethers sobrantes
        _transfer(address(this), msg.sender, _numTokens); // Envio tokens ERC-20
        emit TokenTransfer(address(this), msg.sender, _numTokens);                   
    }

    function returnTokensERC20(uint256 _numTokens) public payable {
        require(_numTokens > 0, "The number of tokens to return must be great to 0");
        require(_numTokens <= balanceTokens(msg.sender), "Not enough tokens to return"); // Balance tokens ERC 20 antes de comprar tokens ERC 20
        
        _transfer(msg.sender, address(this), _numTokens);
        
        payable(msg.sender).transfer(priceTokens(_numTokens)); // Envio ethers al usuario
    }

    // ================================
    // Gestion de la Loteria
    // ================================

    // Precio del boleto de la loteria, que sera pagado en tokens ERC-20
    uint public priceTicket = 5; // 5 tokens ERC 20 por boleto (valor base de la loteria)    
    mapping(address => uint[]) idPerson_ticket; // Relacion persona => boleto comprado
    mapping(uint => address) ADNTicket; // Relacion boleto => ganador
    uint randNonce = 0; // Numero aleatorio que sera el ganador
    uint [] ticketsPurchased; // Boletos de la loteria generados

    function buyTicket(uint _numTickets) public {
        uint TotalPrice = _numTickets * priceTicket; // Precio total de los boletos a comprar
        require(TotalPrice <= balanceTokens(msg.sender), "You don't have enought tokens");

        //  Transferencia de tokens del usuario al smart contract        
        _transfer(msg.sender, address(this), TotalPrice);

        for(uint i = 0; i < _numTickets; i++) {
            uint random;                        
            do {
                random = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce))) % 10000;
                randNonce++;
            } while (ADNTicket[random] != address(0)); // Verificar si el número ya está asignado
            
            // Registro del numero de boleto generado
            idPerson_ticket[msg.sender].push(random);
            ticketsPurchased.push(random);
            ADNTicket[random] = msg.sender; // Registro del ganador del boleto generado (GANADOR)    
            
            //Creacion de un nuevo NFT para el numero de boleto generado
            ticketsNFTs(user_contract[msg.sender]).mintTicket(msg.sender, random);       
        }
     }
  
    function ViewTickets(address _owner) public view returns(uint [] memory) {
        return idPerson_ticket[_owner];
    }

    // Función para retirar ethers acumulados en el contrato
    function withdrawEthers(address payable _to) public onlyOwner {
        require(address(this).balance > 0, "No ethers to withdraw");
        _to.transfer(address(this).balance);
    }
}


// Smart Contract de NFTs
contract mainERC721 is ERC721 {
    
    address public addressLottery;

    constructor() ERC721("main", "MN") {
        addressLottery = msg.sender;
    }

    function safeMint(address _owner, uint256 _ticket) public {
        require(msg.sender == lottery(addressLottery).usersInfo(_owner), "Only the Lottery contract");
        _safeMint(_owner, _ticket);
    }
}

contract ticketsNFTs {
    struct Owner {
        address addressOwner;
        address contractFather;
        address contractNFT;
        address addressUser;
    }
    Owner public owner;

    constructor(address _owner, address _lottery, address _nft) {
        owner = Owner(_owner, _lottery, _nft, address(this)); // Registro de los datos del contrato (Owner)
    }

    function mintTicket(address _owner, uint _ticket) public {
        require(msg.sender == owner.contractFather, "You are not the owner of the contract");
        require(owner.contractNFT != address(0), "Invalid NFT contract address");
        require(_owner != address(0), "Invalid owner address");
        mainERC721(owner.contractNFT).safeMint(_owner, _ticket);
    }
}
