//
//  usbdocumentlib.c
//  usbdocumentlib
//
//  Created by Aldo Ilsant on 20/10/15.
//  Copyright © 2015 aldoilsant. All rights reserved.
//

#include <usbdocumentlib.hpp>

usbdocument::UVCCameraDescription::UVCCameraDescription(UInt16 vendor_id, UInt16 product_id) {
    this->vendor_id=vendor_id;
    this->product_id=product_id;
}

UInt16 usbdocument::UVCCameraDescription::get_vendor_id() {
    return vendor_id;
}
UInt16 usbdocument::UVCCameraDescription::get_product_id() {
    return product_id;
}