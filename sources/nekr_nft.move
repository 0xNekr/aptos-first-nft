module mint_nft::create_nft {
    use std::bcs;
    use std::error;
    use std::signer;
    use std::string::{Self, String};

    use aptos_token::token;
    use aptos_token::token::TokenDataId;

    // Cette structure contient les informations en rapport avec la collection de NFT
    struct ModuleData has key {
        token_data_id: TokenDataId,
    }

    /// Action non authorisé car l'adresse de l'appelant n'est pas celle du propriétaire du module
    const ENOT_AUTHORIZED: u64 = 1;

    /// `init_module` est comme le constructeur d'un module. Il est appelé une seule fois lors de la création du module.
    /// Ici, nous créons une collection de NFT et un token data id pour le NFT que nous allons créer.
    fun init_module(source_account: &signer) {

        // Différentes informations sur la collection de NFT
        let collection_name = string::utf8(b"Nekr's first collection");
        let description = string::utf8(b"This is my first collection ever on Aptos!");
        let collection_uri = string::utf8(b"ipfs://QmVAV8kRmYxcTGmUb9zVGngKfbzsTuT7d5MQ7hPBHGT21F/1.json");
        let token_name = string::utf8(b"Substrapunks");
        let token_uri = string::utf8(b"ipfs://QmVAV8kRmYxcTGmUb9zVGngKfbzsTuT7d5MQ7hPBHGT21F/");

        // Le maximum de token que l'on peut créer, si on met 0, on peut en créer autant que l'on veut
        let maximum_supply = 0;

        // Cette variable définit si nous voulons autoriser la mutation pour la description, l'uri et le maximum de la collection.
        // Ici, nous les mettons tous à faux, ce qui signifie que nous n'autorisons aucune mutation des champs CollectionData.
        // Ordre : [description, uri, maximum]
        let mutate_setting = vector<bool>[ false, false, false ];

        // Création de la collection via la fonction `create_collection` du module `token`
        token::create_collection(source_account, collection_name, description, collection_uri, maximum_supply, mutate_setting);

        // Création du token data id via la fonction `create_tokendata` du module `token`
        let token_data_id = token::create_tokendata(
            source_account, // Le compte qui crée le token
            collection_name, // Le nom de la collection
            token_name, // Le nom du token
            string::utf8(b""), // La description du token
            0, // Le maximum de token que l'on peut créer, si on met 0, on peut en créer autant que l'on veut
            token_uri, // L'uri du token
            signer::address_of(source_account), // L'adresse de reception des royalties
            1,
            0,
            // Cette variable définit si nous voulons autoriser la mutation pour la description, l'uri et le maximum de la collection.
            // Ici, nous les mettons tous à faux, ce qui signifie que nous n'autorisons aucune mutation des champs CollectionData.
            // Ordre : [description, uri, maximum]
            token::create_token_mutability_config(
                &vector<bool>[ false, false, false, false, true ]
            ),
            // We can use property maps to record attributes related to the token.
            // In this example, we are using it to record the receiver's address.
            // We will mutate this field to record the user's address
            // when a user successfully mints a token in the `mint_nft()` function.
            vector<String>[string::utf8(b"given_to")],
            vector<vector<u8>>[b""],
            vector<String>[ string::utf8(b"address") ],
        );

        // Store the token data id within the module, so we can refer to it later
        // when we're minting the NFT and updating its property version.
        move_to(source_account, ModuleData {
            token_data_id,
        });
    }

    /// Mint un NFT au receveur. Notez que nous demandons à deux comptes de signer : le propriétaire du module et le receveur.
    /// Ce n'est pas idéal en production, car nous ne voulons pas signer manuellement chaque transaction. C'est aussi
    /// impraticable/inefficace en général, car nous devons soit implémenter l'exécution différée par nous-mêmes, soit avoir
    /// deux clés à signer en même temps.
    /// Dans la deuxième partie de ce tutoriel, nous introduirons le concept de "compte de ressources" - c'est
    /// un compte contrôlé par des contrats intelligents pour signer automatiquement les transactions. Le compte de ressources est également connu
    /// comme PDA ou compte de contrat intelligent dans les termes généraux de la blockchain.
    public entry fun delayed_mint_event_ticket(module_owner: &signer, receiver: &signer) acquires ModuleData {
        // Assert that the module owner signer is the owner of this module.
        assert!(signer::address_of(module_owner) == @mint_nft, error::permission_denied(ENOT_AUTHORIZED));

        // Mint token to the receiver.
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        let token_id = token::mint_token(module_owner, module_data.token_data_id, 1);
        token::direct_transfer(module_owner, receiver, token_id, 1);

        // Mutate the token properties to update the property version of this token.
        // Note that here we are re-using the same token data id and only updating the property version.
        // This is because we are simply printing edition of the same token, instead of creating
        // tokens with unique names and token uris. The tokens created this way will have the same token data id,
        // but different property versions.
        let (creator_address, collection, name) = token::get_token_data_id_fields(&module_data.token_data_id);
        token::mutate_token_properties(
            module_owner,
            signer::address_of(receiver),
            creator_address,
            collection,
            name,
            0,
            1,
            // Mutate the properties to record the receiveer's address.
            vector<String>[string::utf8(b"given_to")],
            vector<vector<u8>>[bcs::to_bytes(&signer::address_of(receiver))],
            vector<String>[ string::utf8(b"address") ],
        );
    }
}