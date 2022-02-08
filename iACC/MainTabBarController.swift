//	
// Copyright © Essential Developer. All rights reserved.
//

import UIKit

class MainTabBarController: UITabBarController {
	
    private var friendsCache: FriendsCache!
    
    convenience init(friendsCache: FriendsCache) {
		self.init(nibName: nil, bundle: nil)
        self.friendsCache = friendsCache
		self.setupViewController()
	}

	private func setupViewController() {
		viewControllers = [
			makeNav(for: makeFriendsList(), title: "Friends", icon: "person.2.fill"),
			makeTransfersList(),
			makeNav(for: makeCardsList(), title: "Cards", icon: "creditcard.fill")
		]
	}
	
	private func makeNav(for vc: UIViewController, title: String, icon: String) -> UIViewController {
		vc.navigationItem.largeTitleDisplayMode = .always
		
		let nav = UINavigationController(rootViewController: vc)
		nav.tabBarItem.image = UIImage(
			systemName: icon,
			withConfiguration: UIImage.SymbolConfiguration(scale: .large)
		)
		nav.tabBarItem.title = title
		nav.navigationBar.prefersLargeTitles = true
		return nav
	}
	
	private func makeTransfersList() -> UIViewController {
		let sent = makeSentTransfersList()
		sent.navigationItem.title = "Sent"
		sent.navigationItem.largeTitleDisplayMode = .always
		
		let received = makeReceivedTransfersList()
		received.navigationItem.title = "Received"
		received.navigationItem.largeTitleDisplayMode = .always
		
		let vc = SegmentNavigationViewController(first: sent, second: received)
		vc.tabBarItem.image = UIImage(
			systemName: "arrow.left.arrow.right",
			withConfiguration: UIImage.SymbolConfiguration(scale: .large)
		)
		vc.title = "Transfers"
		vc.navigationBar.prefersLargeTitles = true
		return vc
	}
	
	private func makeFriendsList() -> ListViewController {
		let vc = ListViewController()
		vc.fromFriendsScreen = true
        vc.shouldRetry = true
        vc.maxRetryCount = 2
        
        vc.title = "Friends"
        
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: vc, action: #selector(addFriend))
        
         let isPremium = User.shared?.isPremium == true
        
        vc.service = FriendsAPIItemServiceAdapter(cache: isPremium ? friendsCache : NullFriendsCache(), api: FriendsAPI.shared) { [weak vc] item in
            vc?.selectFriend(item)
        }
		return vc
	}
	
	private func makeSentTransfersList() -> ListViewController {
		let vc = ListViewController()
		vc.fromSentTransfersScreen = true
        vc.shouldRetry = true
        vc.maxRetryCount = 1
        vc.longDateStyle = true

        vc.navigationItem.title = "Sent"
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send", style: .done, target: vc, action: #selector(sendMoney))
        
        vc.service = SentTransfersAPIItemServiceAdapter(api: TransfersAPI.shared, select: { [weak vc] item in
            vc?.selectTransfer(item)
        })
        
		return vc
	}
	
	private func makeReceivedTransfersList() -> ListViewController {
		let vc = ListViewController()
		vc.fromReceivedTransfersScreen = true
        vc.shouldRetry = true
        vc.maxRetryCount = 1
        vc.longDateStyle = false
        
        vc.navigationItem.title = "Received"
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Request", style: .done, target: vc, action: #selector(requestMoney))
        
        vc.service = ReceivedTransfersAPIItemServiceAdapter(api: TransfersAPI.shared, select: { [weak vc] item in
            vc?.selectTransfer(item)
        })
        
		return vc
	}
	
	private func makeCardsList() -> ListViewController {
		let vc = ListViewController()
		vc.fromCardsScreen = true
        vc.shouldRetry = false
        
        vc.title = "Cards"
        
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: vc, action: #selector(addCard))
        
        vc.service = CardAPIItemServiceAdapter(api: CardAPI.shared) { [weak vc] item in
            vc?.selectCard(item)
        }
		return vc
	}
}

struct FriendsAPIItemServiceAdapter: ItemsService {
    
    let cache: FriendsCache
    let api: FriendsAPI
    let select: (Friend) -> Void
    
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
       api.loadFriends { result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map { items in
                    cache.save(items)
                    return items.map { item in
                        ItemViewModel(friend: item) { select(item) }
                    }
                })
            }
        }
    }
}

struct CardAPIItemServiceAdapter: ItemsService {
    
    let api: CardAPI
    let select: (Card) -> Void
    
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
        CardAPI.shared.loadCards { result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map { items in
                    items.map { item in
                        ItemViewModel(card: item) { select(item) }
                    }
                })
            }
        }
    }
}

struct SentTransfersAPIItemServiceAdapter: ItemsService {
    
    let api: TransfersAPI
    let select: (Transfer) -> Void
    
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
        
        api.loadTransfers { result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map { items in
                    items.filter{ $0.isSender }.map { item in
                        ItemViewModel(
                            transfer: item,
                            longDateStyle: true) { select(item) }
                    }
                })
            }
        }

    }
}

struct ReceivedTransfersAPIItemServiceAdapter: ItemsService {
    
    let api: TransfersAPI
    let select: (Transfer) -> Void
    
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
        
        api.loadTransfers { result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map { items in
                    items.filter{ !$0.isSender }.map { item in
                        ItemViewModel(
                            transfer: item,
                            longDateStyle: false) { select(item) }
                    }
                })
            }
        }

    }
}


// Null Object Pattern

class NullFriendsCache: FriendsCache {
    override func save(_ newFriends: [Friend]) {}
}
