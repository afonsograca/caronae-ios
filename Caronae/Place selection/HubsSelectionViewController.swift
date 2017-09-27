import UIKit
import SVProgressHUD

@objc protocol HubSelectionDelegate: class {
    func hasSelected(hubs: [String], inCampus campus: String)
}

@objc class HubSelectionViewController: SelectionViewController {
    
    required convenience init(selectionType: SelectionType, hubTypeDirection: HubTypeDirection) {
        self.init()
        self.selectionType = selectionType
        self.hubTypeDirection = hubTypeDirection
    }
    
    @objc enum HubTypeDirection: Int {
        case hubs
        case centers
    }

    weak var delegate: HubSelectionDelegate?
    
    var numberOfCampi = 0
    var hubTypeDirection: HubTypeDirection?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Campus"
        
        SVProgressHUD.show()
        PlaceService.instance.getCampi(hubTypeDirection: hubTypeDirection!, success: { campi, options, colors, shouldReload in
            self.numberOfCampi = campi.count
            self.dictionaryColors = colors
            if self.numberOfCampi == 1 {
                self.selectionLevel = .secondLevel
                self.selectedFirstLevel = campi.first!
                self.levelOptions = options[self.selectedFirstLevel]!.sorted()
                self.colorFirstLevel = self.color(forCell: self.selectedFirstLevel)
                self.secondDelegate = self
                self.configureSecondSelectionIfNeeded()
            } else {
                if self.selectionType == .manySelection {
                    self.levelOptions = [CaronaeAllCampiText]
                }
                self.levelOptions.append(contentsOf: campi)
                self.dictionarySelection = options
            }
            
            if shouldReload {
                self.tableView.reloadData()
            }
            SVProgressHUD.dismiss()
        }, error: { error in
            SVProgressHUD.dismiss()
            NSLog("Error getting campi (\(error.localizedDescription))")
            CaronaeAlertController.presentOkAlert(withTitle: "Não foi possível carregar as localidades", message: "Por favor, tente novamente. \(error.localizedDescription).", handler: {
                self.navigationController?.popToRootViewController(animated: true)
            })
        })
    }
    
    override func hasSelected(selections: [String], inFirstLevel firstLevel: String) {
        super.hasSelected(selections: selections, inFirstLevel: firstLevel)
        
        if self.selectionType == .manySelection && self.numberOfCampi == 1 && selections == [firstLevel] {
            // Selected all hubs of the single campus. Behavior of selecting all campi.
            delegate?.hasSelected(hubs: [CaronaeAllCampiText], inCampus: CaronaeAllCampiText)
            return
        }
        
        delegate?.hasSelected(hubs: selections, inCampus: firstLevel)
    }

}
