//
//  NewClassViewController.swift
//  My Backpack
//
//  Created by Sergiy Momot on 3/17/17.
//  Copyright © 2017 Sergiy Momot. All rights reserved.
//

import UIKit
import CoreData
import DoneHUD

class NewClassViewController: UIViewController
{
    private let lectureDayEntryHeight: CGFloat = 24.0
    
    @IBOutlet weak var classNameField: UITextField!
    @IBOutlet weak var firstLectureDateField: IQDropDownTextField!
    @IBOutlet weak var lastLectureDateField: IQDropDownTextField!
    @IBOutlet weak var daysStackView: UIStackView!
    @IBOutlet weak var dayField: IQDropDownTextField!
    @IBOutlet weak var fromTimeField: IQDropDownTextField!
    @IBOutlet weak var dayViewHeightConstrait: NSLayoutConstraint!
    @IBOutlet weak var toTimeField: IQDropDownTextField!
    
    var delegate: NewClassViewControllerDelegate?
    
    private lazy var lectureDays = [(String, Date, Date)]()
    
    let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    
    fileprivate lazy var toolbar: UIToolbar = {
        let toolbar = UIToolbar()
        toolbar.barStyle = .default
        toolbar.isTranslucent = true
        toolbar.tintColor = .blue
        toolbar.sizeToFit() 
        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(donePicker))
        let space = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolbar.setItems([space, doneButton, space], animated: false)
        toolbar.isUserInteractionEnabled = true
        return toolbar
    }()
    
    private lazy var alert: UIAlertController = {
        let alert = UIAlertController(title: "Error", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            alert.dismiss(animated: true, completion: nil)
        })) 
        return alert
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.classNameField.delegate = self
        self.setupPickers()
    }
    
    @IBAction func addDay(_ sender: Any) {
        guard !self.lectureDays.contains(where: { $0.0 == dayField.selectedItem! }) else {
            self.alert.message = "Class already has \(dayField.selectedItem!) as a lecture day."
            self.present(alert, animated: true, completion: nil)
            return
        }
        
        let text = "\(dayField.selectedItem!),  \(fromTimeField.selectedItem!) - \(toTimeField.selectedItem!)"
        daysStackView.addArrangedSubview(getLectureDayEntry(forText: text))
        UIView.animate(withDuration: 0.5) { 
            self.dayViewHeightConstrait.constant += self.daysStackView.spacing + self.lectureDayEntryHeight
        }
        
        self.lectureDays.append((dayField.selectedItem!, fromTimeField.date!, toTimeField.date!))
    }
    
    @objc fileprivate func removeDay(_ sender: UIButton) {
        sender.superview?.removeFromSuperview()
        UIView.animate(withDuration: 0.5) { 
            self.dayViewHeightConstrait.constant -= self.daysStackView.spacing + self.lectureDayEntryHeight
        }
        
        if let index = self.lectureDays.index(where: { $0.0 == sender.accessibilityIdentifier!}) {
            self.lectureDays.remove(at: index)
        }
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        self.delegate?.newClassViewController(self, didFinishWithSuccess: false)
    }
    
    @IBAction func saveAction(_ sender: Any) {
        var errorMessage: String?
        
        if classNameField.text!.isEmpty {
            errorMessage = "Class name is not specified."
        } else if daysStackView.arrangedSubviews.count == 0 {
            errorMessage = "Class should have at least one lecture day."
        }
        
        guard errorMessage == nil else {
            self.alert.message = errorMessage
            self.present(alert, animated: true, completion: nil)
            return
        }
        
        saveClassToCoreData()
        
        DoneHUD.shared.showInView(self.view, message: "Saved") {
            self.delegate?.newClassViewController(self, didFinishWithSuccess: true)
        }
    }
    
    private func saveClassToCoreData() {
        let newClass = NSEntityDescription.insertNewObject(forEntityName: "Class", into: CoreDataManager.shared.managedContext) as! Class
        
        newClass.name = self.classNameField.text
        newClass.firstLectureDate = self.firstLectureDateField.date as NSDate?
        newClass.lastLectureDate = self.lastLectureDateField.date as NSDate?
        
        for day in lectureDays {
            let lectureDay = NSEntityDescription.insertNewObject(forEntityName: "ClassDay", into: CoreDataManager.shared.managedContext) as! ClassDay
            
            lectureDay.day = Int16(dayNames.index(of: day.0)! + 1)
            
            var components = Calendar.current.dateComponents([.hour, .minute], from: day.1)
            lectureDay.startTime = Int16(components.hour! * 60 + components.minute!)
            
            components = Calendar.current.dateComponents([.hour, .minute], from: day.2)
            lectureDay.endTime = Int16(components.hour! * 60 + components.minute!)
            
            newClass.addToDays(lectureDay)
        }
        
        CoreDataManager.shared.saveContext()
    }
}

fileprivate extension NewClassViewController
{
    func getLectureDayEntry(forText text: String) -> UIView {
        let bgView = UIView()
        bgView.backgroundColor = .clear
        
        let textField = UITextField()
        textField.borderStyle = .roundedRect
        textField.backgroundColor = .white
        textField.font = UIFont(name: "Avenir Next", size: 12)
        textField.isUserInteractionEnabled = false
        textField.text = text
        
        let button = UIButton()
        button.setTitle("Remove", for: .normal)
        button.accessibilityIdentifier = dayField.selectedItem!
        button.setTitleColor(.red, for: .normal)
        button.setTitleColor(.white, for: .highlighted)
        button.titleLabel?.font = UIFont(name: "Avenir Next", size: 14)
        button.addTarget(self, action: #selector(removeDay(_:)), for: .touchUpInside)
        
        bgView.addSubview(textField)
        bgView.addSubview(button)
        
        bgView.addConstraintsWithFormat(format: "H:|[v0]-8-[v1(75)]|", views: textField, button)
        bgView.addConstraintsWithFormat(format: "V:|[v0]|", views: textField)
        bgView.addConstraintsWithFormat(format: "V:|[v0]|", views: button)
        
        return bgView
    }
    
    func setupPickers() {
        firstLectureDateField.dropDownMode = .datePicker
        firstLectureDateField.inputAccessoryView = toolbar
        
        lastLectureDateField.dropDownMode = .datePicker
        lastLectureDateField.inputAccessoryView = toolbar
        
        fromTimeField.dropDownMode = .timePicker
        fromTimeField.inputAccessoryView = toolbar
        fromTimeField.isOptionalDropDown = false
        
        toTimeField.dropDownMode = .timePicker
        toTimeField.inputAccessoryView = toolbar
        toTimeField.isOptionalDropDown = false
        
        dayField.dropDownMode = .textPicker
        dayField.inputAccessoryView = toolbar
        dayField.isOptionalDropDown = false
        dayField.itemList = dayNames
    }
}

extension NewClassViewController: UITextFieldDelegate
{
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.classNameField.resignFirstResponder()
        return true
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if self.classNameField.isEditing {
            self.classNameField.endEditing(true)
        }
    }
    
    @objc fileprivate func donePicker() {
        if firstLectureDateField.isEditing {
            firstLectureDateField.resignFirstResponder()
        } else if lastLectureDateField.isEditing {
            lastLectureDateField.resignFirstResponder()
        } else if dayField.isEditing {
            dayField.resignFirstResponder()
        } else if fromTimeField.isEditing {
            fromTimeField.resignFirstResponder()
        } else {
            toTimeField.resignFirstResponder()
        }
    }
}
