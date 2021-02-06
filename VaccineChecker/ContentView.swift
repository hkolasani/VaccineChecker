//
//  ContentView.swift
//  VaccineChecker
//
//  Created by Hari Kolasani on 2/3/21.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        //Component that checkes for the specific Covid-19 Vaccinations  (both DTSU2-NDC codes and R4-CVX codes)
        VaccineChecker(
                        vaccineType: "COVID-19",
                        vaccineCodes:[
                                    "207":"Moderna",
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
