//
//  VaccineChecker.swift
//  VaccineChecker
//
//  Created by Hari Kolasani on 2/3/21.
//

import SwiftUI
import HealthKit
import ModelsDSTU2
import ModelsR4

struct VaccineChecker: View {

    //the cvx vaccine codes to check for  eg. ["207":"Moderna COVID-19 Vaccine","208":"Pfizer COVID-19 Vaccine"]
    //the ndc vaccine codes to check for  eg. 80777-273-99":"Moderna COVID-19 Vaccine","59267-1000-2":"Pfizer COVID-19 Vaccine"]
    var vaccineCodes:[String:String]
    var vaccineType:String
        
    @State var checking:Bool = false
    @State private var showingAlert = false
    @State private var alertText = ""
    @State private var buttonColor = Color.blue
    @State private var vaccineInfo = ""
    @State private var checkedImage = ""
    
    //vaccienType and VaccineCodes: cvxCodes are for R4 and and ndcCodes are for DTSU2
    init(vaccineType:String, vaccineCodes:[String:String]) {
        self.vaccineType = vaccineType
        self.vaccineCodes = vaccineCodes
    }
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    self.checking = true
                    checkVacccinations()
                }) {
                    HStack {
                        Image(systemName: "staroflife")
                            .font(.title)
                        Text("Check " + self.vaccineType + " Vaccination")
                            .fontWeight(.semibold)
                            .font(.title3)
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(self.buttonColor)
                    .cornerRadius(40)
                }
                .padding()
                .alert(isPresented: $showingAlert) {
                    Alert(title: Text("Error"), message: Text( self.alertText), dismissButton: .default(Text("Got it!")))
                }
                self.checking ? AnyView(ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: Color.yellow))
                                            .scaleEffect(1.5, anchor: .center))
                              : AnyView(EmptyView())
            }
            Label(self.vaccineInfo, systemImage: checkedImage)
        }
    }
    
    //get HealthKit Store Auth and look into Immunization records
    func checkVacccinations() {
        hideMessages()
        let healthStore = HKHealthStore()
        let hkTypes = Set([HKObjectType.clinicalType(forIdentifier: .immunizationRecord)!])
        healthStore.requestAuthorization(toShare: Set(), read: hkTypes) { (success, error) in
            guard success else {
                DispatchQueue.main.async {
                    self.showError(message: "Not Authorized to access Health Records")
                    return
                }
                return
            }
            fecthImmunizations(healthStore:healthStore)
       }
    }
    
    //Query HealthKit Store to fetch Immnunization records and look for vaccinations
    func fecthImmunizations(healthStore: HKHealthStore) {
        let hkType = HKObjectType.clinicalType(forIdentifier: .immunizationRecord)!
        let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        let query = HKSampleQuery(sampleType: hkType, predicate: nil, limit: 100, sortDescriptors: sortDescriptors) {(_, samplesOrNil, error) in
            DispatchQueue.main.async {
                self.checking = false
                guard let immunizations = samplesOrNil else {
                    DispatchQueue.main.async {
                        self.showError(message: "Unable to find any Immunization Records")
                        return
                    }
                    return
                }
                var foundVaccination = false
                self.vaccineInfo = "No Vaccination Records Found"
                for immunization in immunizations {
                    foundVaccination = findVaccination(immunizationRecord:(immunization as? HKClinicalRecord)!)
                    if(foundVaccination) {
                        break
                    }
                }
                self.buttonColor = foundVaccination ? Color.green : Color.red
                self.checkedImage = foundVaccination ? "checkmark.rectangle.fill" : "xmark.circle.fill"
            }
        }
        
        healthStore.execute(query)
    }
    
    //parse FHIR data of Immunization HKClinical Record, and look for the vaccination code.
    func findVaccination(immunizationRecord:HKClinicalRecord) -> Bool {
        
        var foundVaccination = false
        
        guard let fhirResource = immunizationRecord.fhirResource else {
            self.showError(message:"Unable to get FHIR Resource from Immunization Record")
            return foundVaccination
        }
        do {
            let decoder = JSONDecoder()
            var vaccineCode = "XXXXXX"
            var vaccineDate = ""
            if #available(iOS 14.0, *) {
                switch fhirResource.fhirVersion.fhirRelease {
                case .dstu2:
                    let immunization =  try decoder.decode(ModelsDSTU2.Immunization.self, from: fhirResource.data)
                    vaccineCode = (immunization.vaccineCode.coding?[0].code?.value!.string)!
                    vaccineDate = (immunization.date?.value!.description)!
                case .r4:
                    let immunization =  try decoder.decode(ModelsR4.Immunization.self, from: fhirResource.data)
                    vaccineCode = (immunization.vaccineCode.coding?[0].code?.value!.string)!
                    vaccineDate = (immunization.recorded?.value!.description)!
                default:
                    self.showingAlert = true
                    self.alertText = "Invalid FHIR Data"
                }
            } else {
                let immunization = try decoder.decode(ModelsDSTU2.Immunization.self, from: fhirResource.data)
                vaccineCode = (immunization.vaccineCode.coding?[0].code?.value!.string)!
                vaccineDate = (immunization.date?.value!.description)!
            }
            
            if let vaccineDesc = vaccineCodes[vaccineCode] {
                self.vaccineInfo = vaccineDesc + ". " + vaccineDate
                foundVaccination = true
            }
            
            return foundVaccination
            
        } catch {
            self.showError(message:"Failed to decode \(fhirResource.resourceType) using FHIRModels: \(error)")
            return foundVaccination
        }
    }
  
    func showError(message:String) {
        self.showingAlert = true
        self.alertText = message
    }
    func hideMessages() {
        self.showingAlert = false
        self.alertText = ""
        self.vaccineInfo = ""
        self.checkedImage = ""
    }
}

enum FHIRResourceDecodingError: Error {
    case notAnHKClinicalRecord(HKSample)
    case noFHIRResourcePresent(HKClinicalRecord)
    case resourceTypeNotSupported(HKFHIRResourceType)
    
    @available(iOS 14.0, *)
    case versionNotSupported(HKFHIRVersion)
}

struct VaccineChecker_Previews: PreviewProvider {
    static var previews: some View {
        VaccineChecker(
                        vaccineType: "COVID-19",
                        vaccineCodes:[
                                    //"207":"Moderna",
                                    "135":"Moderna",
                                    "208":"Pfizer",
                                    "210":"AstraZeneca",
                                    "212":"Janssen",
                                    "80777-273-99":"Moderna",
                                    "59267-1000-2":"Pfizer",
                                    "59267-1000-3":"Pfizer",
                                    "0310-1222-15":"AstraZeneca",
                                    "59676-580-15":"Janssen"
                        ]
            )
    }
}
